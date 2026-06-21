// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:sqflite/sqflite.dart';

import '../models/steam_purchase.dart';
import 'app_database.dart';
import 'steam_store_search_text.dart';

/// Ergebnis eines Batch-Imports.
///
/// Neben neu eingefuegten Kaeufen wird gezaehlt, wie viele Zeilen wegen einer
/// bereits vorhandenen Kauf-Signatur uebersprungen wurden. Die importierten
/// Modelle koennen Folgeprozesse wie Laengenschaetzungen gezielt weiterreichen.
class SteamPurchaseImportResult {
  final int importedCount;
  final int skippedDuplicateCount;
  final List<SteamPurchase> importedPurchases;

  SteamPurchaseImportResult({
    required this.importedCount,
    required this.skippedDuplicateCount,
    List<SteamPurchase> importedPurchases = const [],
  }) : importedPurchases = List.unmodifiable(importedPurchases);

  int get totalCount => importedCount + skippedDuplicateCount;
}

/// Repository fuer CRUD-Operationen auf `steam_purchases`.
///
/// Die Klasse haelt SQL-Zugriff aus den Widgets heraus und gibt nur
/// `SteamPurchase`-Modelle zurueck.
class SteamPurchaseRepository {
  static const String _tableName = 'steam_purchases';

  final Future<Database> Function() _databaseProvider;

  SteamPurchaseRepository({Future<Database> Function()? databaseProvider})
    : _databaseProvider = databaseProvider ?? (() => AppDatabase.instance);

  /// Laedt alle Kaeufe, neueste zuerst.
  Future<List<SteamPurchase>> getAllPurchases() async {
    final db = await _databaseProvider();

    final maps = await db.query(_tableName, orderBy: 'purchase_date DESC');

    return maps.map(SteamPurchase.fromMap).toList();
  }

  /// Fuegt einen einzelnen Kauf ein und gibt ihn mit der neuen Datenbank-ID
  /// zurueck.
  Future<SteamPurchase> addPurchase(SteamPurchase purchase) async {
    final db = await _databaseProvider();

    final id = await db.insert(
      _tableName,
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return purchase.copyWith(id: id);
  }

  /// Importiert mehrere Kaeufe in einer Transaktion.
  ///
  /// Die IDs werden verworfen, damit CSV-Importe keine bestehenden Zeilen
  /// ueberschreiben.
  Future<int> addPurchases(List<SteamPurchase> purchases) async {
    final result = await importPurchases(purchases);

    return result.importedCount;
  }

  /// Importiert mehrere Kaeufe und ueberspringt bereits vorhandene Eintraege.
  ///
  /// Duplikate werden ueber stabile Kaufdaten erkannt. Nachtraeglich gepflegte
  /// Felder wie Spielzeit, Steam-App-ID, Status, Notiz oder Laengenschaetzungen
  /// bleiben fuer den Vergleich bewusst unberuecksichtigt.
  Future<SteamPurchaseImportResult> importPurchases(
    List<SteamPurchase> purchases,
  ) async {
    if (purchases.isEmpty) {
      return SteamPurchaseImportResult(
        importedCount: 0,
        skippedDuplicateCount: 0,
      );
    }

    final db = await _databaseProvider();

    return db.transaction((transaction) async {
      final existingRows = await transaction.query(_tableName);
      final knownSignatures = existingRows
          .map(SteamPurchase.fromMap)
          .map(_PurchaseImportSignature.fromPurchase)
          .toSet();
      final batch = transaction.batch();
      final importedPurchases = <SteamPurchase>[];
      var importedCount = 0;
      var skippedDuplicateCount = 0;

      for (final purchase in purchases) {
        final signature = _PurchaseImportSignature.fromPurchase(purchase);

        if (!knownSignatures.add(signature)) {
          skippedDuplicateCount++;
          continue;
        }

        final map = purchase.toMap();
        map['id'] = null;

        batch.insert(
          _tableName,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        importedPurchases.add(purchase);
        importedCount++;
      }

      if (importedCount > 0) {
        await batch.commit(noResult: true);
      }

      return SteamPurchaseImportResult(
        importedCount: importedCount,
        skippedDuplicateCount: skippedDuplicateCount,
        importedPurchases: importedPurchases,
      );
    });
  }

  Future<void> updatePurchase(SteamPurchase purchase) async {
    // Updates brauchen eine bestehende ID, sonst waere nicht eindeutig, welche
    // Zeile geaendert werden soll.
    if (purchase.id == null) {
      throw ArgumentError('Cannot update purchase without id.');
    }

    final db = await _databaseProvider();

    await db.update(
      _tableName,
      purchase.toMap(),
      where: 'id = ?',
      whereArgs: [purchase.id],
    );
  }

  Future<int> updateSteamAppIds(Map<int, int> steamAppIdsByPurchaseId) async {
    if (steamAppIdsByPurchaseId.isEmpty) {
      return 0;
    }

    final db = await _databaseProvider();

    return db.transaction((transaction) async {
      final batch = transaction.batch();

      for (final entry in steamAppIdsByPurchaseId.entries) {
        // Nur noch unverknuepfte Kaeufe werden gesetzt, damit manuelle Links
        // nicht versehentlich ueberschrieben werden.
        batch.update(
          _tableName,
          {'steam_app_id': entry.value},
          where: 'id = ? AND steam_app_id IS NULL',
          whereArgs: [entry.key],
        );
      }

      final results = await batch.commit();
      var updatedCount = 0;

      for (final result in results) {
        if (result is int) {
          updatedCount += result;
        }
      }

      return updatedCount;
    });
  }

  Future<int> updatePlaytimeHoursBySteamAppId(
    Map<int, double> playtimeHoursBySteamAppId,
  ) async {
    if (playtimeHoursBySteamAppId.isEmpty) {
      return 0;
    }

    final db = await _databaseProvider();

    return db.transaction((transaction) async {
      final batch = transaction.batch();

      for (final entry in playtimeHoursBySteamAppId.entries) {
        // Die Toleranz vermeidet Schreibzugriffe, wenn sich nur Rundungsrauschen
        // in der Spielzeit unterscheidet.
        batch.update(
          _tableName,
          {'playtime_hours': entry.value},
          where:
              'steam_app_id = ? AND '
              '(playtime_hours IS NULL OR ABS(playtime_hours - ?) > 0.0001)',
          whereArgs: [entry.key, entry.value],
        );
      }

      final results = await batch.commit();
      var updatedCount = 0;

      for (final result in results) {
        if (result is int) {
          updatedCount += result;
        }
      }

      return updatedCount;
    });
  }

  Future<void> deletePurchase(int id) async {
    final db = await _databaseProvider();

    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _databaseProvider();

    await db.delete(_tableName);
  }
}

/// Vergleichsschluessel fuer CSV-/Batch-Importe.
///
/// Preis und Kaufdatum bleiben Teil der Signatur, damit gleichnamige Spiele
/// nicht zu aggressiv zusammengefasst werden. Dynamische Felder bleiben draussen.
class _PurchaseImportSignature {
  final String purchaseDate;
  final SteamPurchaseType purchaseType;
  final String gameName;
  final String edition;
  final String dlcName;
  final String price;

  const _PurchaseImportSignature({
    required this.purchaseDate,
    required this.purchaseType,
    required this.gameName,
    required this.edition,
    required this.dlcName,
    required this.price,
  });

  factory _PurchaseImportSignature.fromPurchase(SteamPurchase purchase) {
    return _PurchaseImportSignature(
      purchaseDate: _dateKey(purchase.purchaseDate),
      purchaseType: purchase.purchaseType,
      gameName: _textKey(purchase.gameName),
      edition: _textKey(purchase.edition),
      dlcName: purchase.purchaseType == SteamPurchaseType.dlc
          ? _textKey(purchase.dlcName)
          : '',
      price: purchase.price.toStringAsFixed(4),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _PurchaseImportSignature &&
        purchaseDate == other.purchaseDate &&
        purchaseType == other.purchaseType &&
        gameName == other.gameName &&
        edition == other.edition &&
        dlcName == other.dlcName &&
        price == other.price;
  }

  @override
  int get hashCode {
    return Object.hash(
      purchaseDate,
      purchaseType,
      gameName,
      edition,
      dlcName,
      price,
    );
  }

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _textKey(String? value) {
    final trimmedValue = value?.trim();

    if (trimmedValue == null || trimmedValue.isEmpty) {
      return '';
    }

    return normalizeSteamStoreSearchText(trimmedValue);
  }
}
