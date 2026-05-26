import 'package:sqflite/sqflite.dart';

import '../models/steam_purchase.dart';
import 'app_database.dart';

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
    if (purchases.isEmpty) {
      return 0;
    }

    final db = await _databaseProvider();

    return db.transaction((transaction) async {
      final batch = transaction.batch();

      for (final purchase in purchases) {
        final map = purchase.toMap();
        map['id'] = null;

        batch.insert(
          _tableName,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);

      return purchases.length;
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
