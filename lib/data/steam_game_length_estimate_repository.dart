import 'package:sqflite/sqflite.dart';

import '../models/steam_game_length_estimate.dart';
import '../models/steam_purchase.dart';
import 'app_database.dart';
import 'steam_store_search_text.dart';

/// Repository fuer die separate Hintergrunddatenbank mit Spiel-Laengen.
///
/// Die Eintraege erzeugen keine Kaeufe und tauchen deshalb nicht in der
/// Kaufuebersicht auf. Sie werden nur fuer Vorschlaege und den separaten
/// Laengenschaetzungs-CSV-Export verwendet.
class SteamGameLengthEstimateRepository {
  static const String tableName = 'steam_game_length_estimates';

  final Future<Database> Function() _databaseProvider;
  final DateTime Function() _now;

  SteamGameLengthEstimateRepository({
    Future<Database> Function()? databaseProvider,
    DateTime Function()? now,
  }) : _databaseProvider = databaseProvider ?? (() => AppDatabase.instance),
       _now = now ?? DateTime.now;

  Future<List<SteamGameLengthEstimate>> getAllEstimates() async {
    final db = await _databaseProvider();
    final rows = await db.query(
      tableName,
      orderBy: 'LOWER(game_name) ASC, id ASC',
    );

    return rows.map(SteamGameLengthEstimate.fromMap).toList();
  }

  Future<SteamGameLengthEstimate?> findEstimate({
    int? steamAppId,
    String? gameName,
  }) async {
    final db = await _databaseProvider();
    final normalizedName = _normalizeGameName(gameName);

    if (steamAppId != null) {
      final rows = await db.query(
        tableName,
        where: 'steam_app_id = ?',
        whereArgs: [steamAppId],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return SteamGameLengthEstimate.fromMap(rows.single);
      }
    }

    if (normalizedName == null) {
      return null;
    }

    final rows = await db.query(
      tableName,
      where: 'normalized_game_name = ?',
      whereArgs: [normalizedName],
      limit: 1,
    );

    return rows.isEmpty ? null : SteamGameLengthEstimate.fromMap(rows.single);
  }

  Future<int> upsertEstimates(
    Iterable<SteamGameLengthEstimate> estimates,
  ) async {
    final cleanEstimates = estimates
        .where((estimate) => estimate.hasAnyEstimate)
        .where((estimate) => _normalizeGameName(estimate.gameName) != null)
        .toList(growable: false);

    if (cleanEstimates.isEmpty) {
      return 0;
    }

    final db = await _databaseProvider();

    return db.transaction((transaction) async {
      var written = 0;

      for (final estimate in cleanEstimates) {
        await _upsertEstimate(transaction, estimate);
        written++;
      }

      return written;
    });
  }

  Future<int> upsertPurchases(Iterable<SteamPurchase> purchases) {
    return upsertEstimates(
      purchases
          .where(_hasPurchaseLengthEstimate)
          .map(_estimateFromPurchase)
          .toList(growable: false),
    );
  }

  Future<void> upsertPurchaseEstimate(SteamPurchase purchase) async {
    if (!_hasPurchaseLengthEstimate(purchase)) {
      return;
    }

    await upsertEstimates([_estimateFromPurchase(purchase)]);
  }

  Future<void> _upsertEstimate(
    Transaction transaction,
    SteamGameLengthEstimate estimate,
  ) async {
    final normalizedName = _normalizeGameName(estimate.gameName)!;
    final matchingRows = await _findMatchingRows(
      transaction,
      normalizedName: normalizedName,
      steamAppId: estimate.steamAppId,
    );
    final map = _toMap(
      estimate,
      normalizedName,
      existing: matchingRows.isEmpty ? null : matchingRows.first,
    );

    if (matchingRows.isEmpty) {
      await transaction.insert(tableName, map);
      return;
    }

    final targetId = matchingRows.first['id'] as int;
    final duplicateIds = matchingRows
        .skip(1)
        .map((row) => row['id'] as int)
        .toList(growable: false);

    if (duplicateIds.isNotEmpty) {
      // Bei Importen aus verschiedenen Quellen koennen Name und Steam-App-ID
      // alte getrennte Eintraege treffen. Vor dem Update werden sie zu einem
      // Ziel zusammengefuehrt, damit die Unique-Indizes gueltig bleiben.
      await transaction.delete(
        tableName,
        where: 'id IN (${List.filled(duplicateIds.length, '?').join(',')})',
        whereArgs: duplicateIds,
      );
    }

    await transaction.update(
      tableName,
      map,
      where: 'id = ?',
      whereArgs: [targetId],
    );
  }

  Future<List<Map<String, Object?>>> _findMatchingRows(
    Transaction transaction, {
    required String normalizedName,
    required int? steamAppId,
  }) {
    if (steamAppId == null) {
      return transaction.query(
        tableName,
        where: 'normalized_game_name = ?',
        whereArgs: [normalizedName],
        limit: 1,
      );
    }

    return transaction.rawQuery(
      '''
      SELECT *
      FROM $tableName
      WHERE steam_app_id = ?
         OR normalized_game_name = ?
      ORDER BY
        CASE WHEN steam_app_id = ? THEN 0 ELSE 1 END,
        id ASC
      ''',
      [steamAppId, normalizedName, steamAppId],
    );
  }

  Map<String, Object?> _toMap(
    SteamGameLengthEstimate estimate,
    String normalizedName, {
    Map<String, Object?>? existing,
  }) {
    return {
      'game_name': estimate.gameName.trim(),
      'normalized_game_name': normalizedName,
      'steam_app_id': estimate.steamAppId ?? existing?['steam_app_id'],
      'main_story_hours':
          estimate.mainStoryHours ?? existing?['main_story_hours'],
      'main_extra_hours':
          estimate.mainExtraHours ?? existing?['main_extra_hours'],
      'completionist_hours':
          estimate.completionistHours ?? existing?['completionist_hours'],
      'updated_at': _now().toIso8601String(),
    };
  }

  static bool _hasPurchaseLengthEstimate(SteamPurchase purchase) {
    if (purchase.purchaseType != SteamPurchaseType.game) {
      return false;
    }

    return purchase.mainStoryHours != null ||
        purchase.mainExtraHours != null ||
        purchase.completionistHours != null;
  }

  static SteamGameLengthEstimate _estimateFromPurchase(SteamPurchase purchase) {
    return SteamGameLengthEstimate(
      gameName: purchase.gameName,
      steamAppId: purchase.steamAppId,
      mainStoryHours: purchase.mainStoryHours,
      mainExtraHours: purchase.mainExtraHours,
      completionistHours: purchase.completionistHours,
    );
  }

  static String? _normalizeGameName(String? value) {
    final trimmedValue = value?.trim();

    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    return normalizeSteamStoreSearchText(trimmedValue);
  }
}
