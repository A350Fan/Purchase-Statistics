// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:sqflite/sqflite.dart';

import '../models/collection_item.dart';
import '../models/steam_collection.dart';
import '../models/steam_game_metadata.dart';
import '../models/steam_purchase.dart';
import 'app_database.dart';

/// Kleiner Metadaten-Auszug, der in Sammlungsdetails neben einem Kauf angezeigt
/// wird.
class CollectionPurchaseMetadata {
  final DateTime? releaseDate;
  final String? releaseDateText;

  const CollectionPurchaseMetadata({this.releaseDate, this.releaseDateText});

  factory CollectionPurchaseMetadata.fromMap(Map<String, Object?> map) {
    return CollectionPurchaseMetadata(
      releaseDate: _parseOptionalDate(map['release_date']),
      releaseDateText: _nullableString(map['release_date_text']),
    );
  }

  bool get hasReleaseInfo =>
      releaseDate != null ||
      (releaseDateText != null && releaseDateText!.isNotEmpty);

  static DateTime? _parseOptionalDate(Object? value) {
    final text = _nullableString(value);

    if (text == null) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static String? _nullableString(Object? value) {
    if (value is! String) {
      return null;
    }

    final text = value.trim();

    return text.isEmpty ? null : text;
  }
}

/// Repository fuer manuelle und automatische Sammlungen.
///
/// Manuelle Sammlungen speichern konkrete `CollectionItem`s. Automatische
/// Sammlungen speichern Regeln und werden ueber SQL-Abfragen dynamisch aus
/// Kaeufen und Steam-Metadaten berechnet.
class SteamCollectionRepository {
  static const String collectionsTable = 'collections';
  static const String collectionItemsTable = 'collection_items';
  static const String _purchasesTable = 'steam_purchases';
  static const String _metadataTable = 'steam_game_metadata';
  static const String _metadataValuesTable = 'steam_game_metadata_values';

  final Future<Database> Function() _databaseProvider;
  final DateTime Function() _now;

  SteamCollectionRepository({
    Future<Database> Function()? databaseProvider,
    DateTime Function()? now,
  }) : _databaseProvider = databaseProvider ?? (() => AppDatabase.instance),
       _now = now ?? DateTime.now;

  Future<List<SteamCollection>> getCollections() async {
    final db = await _databaseProvider();
    final maps = await db.query(
      collectionsTable,
      orderBy: 'created_at DESC, id DESC',
    );

    return maps.map(SteamCollection.fromMap).toList();
  }

  Future<Map<int, int>> getItemCountsByCollection() async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''
      SELECT ci.collection_id, COUNT(*) AS item_count
      FROM $collectionItemsTable ci
      INNER JOIN $collectionsTable c ON c.id = ci.collection_id
      WHERE c.collection_type = ?
      GROUP BY ci.collection_id
    ''',
      [SteamCollectionType.manual.storageValue],
    );

    return {
      for (final row in rows)
        row['collection_id'] as int: (row['item_count'] as int?) ?? 0,
    };
  }

  /// Liefert vorhandene Werte fuer ein Metadatenfeld, damit der
  /// Sammlungsdialog sinnvolle Regelwerte anbieten kann.
  Future<List<String>> getAvailableMetadataRuleValues(
    SteamMetadataField field,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''
      SELECT TRIM(value) AS metadata_value
      FROM $_metadataValuesTable
      WHERE field = ?
        AND TRIM(value) <> ''
      GROUP BY LOWER(TRIM(value))
      ORDER BY LOWER(TRIM(value)) ASC
      ''',
      [field.storageValue],
    );

    return rows
        .map((row) => row['metadata_value'] as String)
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }

  Future<int> countPurchasesForAutomaticCollection(
    SteamCollection collection,
  ) async {
    final ruleField = collection.ruleField;
    final ruleValue = collection.ruleValue?.trim();

    if (!collection.isAutomatic ||
        ruleField == null ||
        ruleValue == null ||
        ruleValue.isEmpty) {
      return 0;
    }

    final db = await _databaseProvider();

    // Titelsuchen vergleichen gegen Kaufname, DLC-Name, Edition und den von
    // Steam geladenen Namen.
    if (ruleField == SteamCollectionRuleField.titleContains) {
      final normalizedRuleValue = _normalizeRuleValue(ruleValue);
      final purchaseTypeArgs = _automaticPurchaseTypeArgs(collection);
      final rows = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT p.id) AS item_count
        FROM $_purchasesTable p
        LEFT JOIN $_metadataTable m ON m.steam_app_id = p.steam_app_id
        WHERE ${_titleContainsWhereClause('p', 'm')}
          ${_automaticPurchaseTypeWhereClause(collection, 'p')}
        ''',
        [...List.filled(4, normalizedRuleValue), ...purchaseTypeArgs],
      );

      return (rows.single['item_count'] as int?) ?? 0;
    }

    final metadataRule = collection.metadataRule;

    if (metadataRule == null) {
      return 0;
    }

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT p.id) AS item_count
      FROM $_purchasesTable p
      INNER JOIN $_metadataValuesTable mv
        ON mv.steam_app_id = p.steam_app_id
      WHERE mv.field = ?
        AND LOWER(TRIM(mv.value)) = LOWER(TRIM(?))
        ${_automaticPurchaseTypeWhereClause(collection, 'p')}
      ''',
      [
        metadataRule.field.storageValue,
        metadataRule.value,
        ..._automaticPurchaseTypeArgs(collection),
      ],
    );

    return (rows.single['item_count'] as int?) ?? 0;
  }

  Future<List<SteamPurchase>> getPurchasesForAutomaticCollection(
    SteamCollection collection,
  ) async {
    final ruleField = collection.ruleField;
    final ruleValue = collection.ruleValue?.trim();

    if (!collection.isAutomatic ||
        ruleField == null ||
        ruleValue == null ||
        ruleValue.isEmpty) {
      return [];
    }

    final db = await _databaseProvider();

    // Automatische Titelsammlungen brauchen keinen Join auf die Wertetabelle,
    // weil sie nur Textspalten durchsuchen.
    if (ruleField == SteamCollectionRuleField.titleContains) {
      final normalizedRuleValue = _normalizeRuleValue(ruleValue);
      final purchaseTypeArgs = _automaticPurchaseTypeArgs(collection);
      final maps = await db.rawQuery(
        '''
        SELECT DISTINCT p.*
        FROM $_purchasesTable p
        LEFT JOIN $_metadataTable m ON m.steam_app_id = p.steam_app_id
        WHERE ${_titleContainsWhereClause('p', 'm')}
          ${_automaticPurchaseTypeWhereClause(collection, 'p')}
        ORDER BY ${_automaticPurchaseOrderBy(collection.sortMode)}
        ''',
        [...List.filled(4, normalizedRuleValue), ...purchaseTypeArgs],
      );

      return maps.map(SteamPurchase.fromMap).toList();
    }

    final metadataRule = collection.metadataRule;

    if (metadataRule == null) {
      return [];
    }

    final maps = await db.rawQuery(
      '''
      SELECT DISTINCT p.*
      FROM $_purchasesTable p
      INNER JOIN $_metadataValuesTable mv
        ON mv.steam_app_id = p.steam_app_id
      LEFT JOIN $_metadataTable m ON m.steam_app_id = p.steam_app_id
      WHERE mv.field = ?
        AND LOWER(TRIM(mv.value)) = LOWER(TRIM(?))
        ${_automaticPurchaseTypeWhereClause(collection, 'p')}
      ORDER BY ${_automaticPurchaseOrderBy(collection.sortMode)}
      ''',
      [
        metadataRule.field.storageValue,
        metadataRule.value,
        ..._automaticPurchaseTypeArgs(collection),
      ],
    );

    return maps.map(SteamPurchase.fromMap).toList();
  }

  Future<int> insertCollection(SteamCollection collection) async {
    final db = await _databaseProvider();

    return db.insert(collectionsTable, collection.toMap());
  }

  Future<int> updateCollection(SteamCollection collection) async {
    if (collection.id == null) {
      throw ArgumentError('Cannot update collection without id.');
    }

    final db = await _databaseProvider();

    return db.update(
      collectionsTable,
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
  }

  Future<int> deleteCollection(int id) async {
    final db = await _databaseProvider();

    return db.delete(collectionsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CollectionItem>> getItemsForCollection(
    int collectionId, {
    SteamCollectionSortMode sortMode = SteamCollectionSortMode.manual,
  }) async {
    final db = await _databaseProvider();

    // Bei nicht-manueller Sortierung werden die Items zusammen mit Kauf- und
    // Metadaten geladen, weil Release-Daten nicht im Item selbst stehen.
    if (sortMode != SteamCollectionSortMode.manual) {
      final maps = await db.rawQuery(
        '''
        SELECT ci.*
        FROM $collectionItemsTable ci
        INNER JOIN $_purchasesTable p ON p.id = ci.purchase_id
        LEFT JOIN $_metadataTable m ON m.steam_app_id = p.steam_app_id
        WHERE ci.collection_id = ?
        ORDER BY ${_collectionItemOrderBy(sortMode)}
        ''',
        [collectionId],
      );

      return maps.map(CollectionItem.fromMap).toList();
    }

    final maps = await db.query(
      collectionItemsTable,
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'custom_order ASC, created_at ASC, id ASC',
    );

    return maps.map(CollectionItem.fromMap).toList();
  }

  Future<Map<int, CollectionPurchaseMetadata>> getPurchaseMetadataByIds(
    Iterable<int> purchaseIds,
  ) async {
    final ids = purchaseIds.toSet().toList();

    if (ids.isEmpty) {
      return {};
    }

    // Platzhalter werden dynamisch erzeugt, damit die Query weiterhin
    // parameterisiert bleibt und keine IDs in SQL-Strings interpoliert werden.
    final db = await _databaseProvider();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.rawQuery('''
      SELECT
        p.id AS purchase_id,
        m.release_date,
        m.release_date_text
      FROM $_purchasesTable p
      LEFT JOIN $_metadataTable m ON m.steam_app_id = p.steam_app_id
      WHERE p.id IN ($placeholders)
      ''', ids);
    final metadataByPurchaseId = <int, CollectionPurchaseMetadata>{};

    for (final row in rows) {
      final purchaseId = row['purchase_id'] as int;
      final metadata = CollectionPurchaseMetadata.fromMap(row);

      if (metadata.hasReleaseInfo) {
        metadataByPurchaseId[purchaseId] = metadata;
      }
    }

    return metadataByPurchaseId;
  }

  Future<Set<int>> getCollectionIdsForPurchase(int purchaseId) async {
    final db = await _databaseProvider();
    final maps = await db.rawQuery(
      '''
      SELECT ci.collection_id
      FROM $collectionItemsTable ci
      INNER JOIN $collectionsTable c ON c.id = ci.collection_id
      WHERE ci.purchase_id = ?
        AND c.collection_type = ?
      ''',
      [purchaseId, SteamCollectionType.manual.storageValue],
    );

    return maps.map((map) => map['collection_id'] as int).toSet();
  }

  Future<void> replaceCollectionsForPurchase({
    required int purchaseId,
    required Set<int> collectionIds,
  }) async {
    final db = await _databaseProvider();

    await db.transaction((transaction) async {
      // Nur manuelle Sammlungen duerfen direkt zugewiesen werden; automatische
      // Sammlungen ergeben sich aus Regeln.
      final manualCollectionIds = await _getManualCollectionIds(transaction);
      final targetCollectionIds = collectionIds.intersection(
        manualCollectionIds,
      );
      final existingRows = await transaction.rawQuery(
        '''
        SELECT ci.collection_id
        FROM $collectionItemsTable ci
        INNER JOIN $collectionsTable c ON c.id = ci.collection_id
        WHERE ci.purchase_id = ?
          AND c.collection_type = ?
        ''',
        [purchaseId, SteamCollectionType.manual.storageValue],
      );
      final existingCollectionIds = existingRows
          .map((row) => row['collection_id'] as int)
          .toSet();
      final collectionIdsToRemove = existingCollectionIds.difference(
        targetCollectionIds,
      );
      final collectionIdsToAdd = targetCollectionIds.difference(
        existingCollectionIds,
      );

      // Entfernen und Hinzufuegen passieren in derselben Transaktion, damit die
      // UI nie einen halb aktualisierten Zuordnungsstand sieht.
      if (collectionIdsToRemove.isNotEmpty) {
        await transaction.delete(
          collectionItemsTable,
          where:
              'purchase_id = ? AND collection_id IN (${List.filled(collectionIdsToRemove.length, '?').join(', ')})',
          whereArgs: [purchaseId, ...collectionIdsToRemove],
        );
      }

      final batch = transaction.batch();

      for (final collectionId in collectionIdsToAdd) {
        final customOrder = await _nextCustomOrder(transaction, collectionId);

        batch.insert(collectionItemsTable, {
          'collection_id': collectionId,
          'purchase_id': purchaseId,
          'custom_order': customOrder,
          'created_at': _now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      if (collectionIdsToAdd.isNotEmpty) {
        await batch.commit(noResult: true);
      }
    });
  }

  Future<int> addPurchaseToCollection({
    required int collectionId,
    required int purchaseId,
  }) async {
    final db = await _databaseProvider();

    // Manuelle Eingriffe in automatische Sammlungen wuerden die Regel-Logik
    // unterlaufen und sind deshalb blockiert.
    if (!await _isManualCollection(db, collectionId)) {
      throw ArgumentError(
        'Cannot manually assign purchases to an automatic collection.',
      );
    }

    final existingItems = await db.query(
      collectionItemsTable,
      columns: ['id'],
      where: 'collection_id = ? AND purchase_id = ?',
      whereArgs: [collectionId, purchaseId],
      limit: 1,
    );

    if (existingItems.isNotEmpty) {
      return existingItems.single['id'] as int;
    }

    final item = CollectionItem.create(
      collectionId: collectionId,
      purchaseId: purchaseId,
      customOrder: await _nextCustomOrder(db, collectionId),
      now: _now,
    );

    return db.insert(collectionItemsTable, item.toMap());
  }

  Future<void> updateCollectionItemOrder({
    required int collectionId,
    required List<int> itemIds,
  }) async {
    final db = await _databaseProvider();

    await db.transaction((transaction) async {
      final batch = transaction.batch();

      // Die Reihenfolge wird als fortlaufender Index gespeichert. Das macht die
      // manuelle Sortierung stabil und einfach wiederherstellbar.
      for (var index = 0; index < itemIds.length; index++) {
        batch.update(
          collectionItemsTable,
          {'custom_order': index},
          where: 'id = ? AND collection_id = ?',
          whereArgs: [itemIds[index], collectionId],
        );
      }

      if (itemIds.isNotEmpty) {
        await batch.commit(noResult: true);
      }
    });
  }

  Future<int> removePurchaseFromCollection({
    required int collectionId,
    required int purchaseId,
  }) async {
    final db = await _databaseProvider();

    return db.delete(
      collectionItemsTable,
      where: 'collection_id = ? AND purchase_id = ?',
      whereArgs: [collectionId, purchaseId],
    );
  }

  String _titleContainsWhereClause(String purchaseAlias, String metadataAlias) {
    // SQL-Snippet fuer automatische Titelsammlungen. Die Aliasse machen das
    // Snippet in COUNT- und SELECT-Abfragen wiederverwendbar.
    return '''
      (
        INSTR(LOWER($purchaseAlias.game_name), ?) > 0
        OR INSTR(LOWER(COALESCE($purchaseAlias.dlc_name, '')), ?) > 0
        OR INSTR(LOWER(COALESCE($purchaseAlias.edition, '')), ?) > 0
        OR INSTR(LOWER(COALESCE($metadataAlias.name, '')), ?) > 0
      )
    ''';
  }

  String _normalizeRuleValue(String value) {
    return value.trim().toLowerCase();
  }

  String _automaticPurchaseTypeWhereClause(
    SteamCollection collection,
    String purchaseAlias,
  ) {
    // Automatische Sammlungen schliessen DLCs standardmaessig aus. Wenn
    // `includeDlcs` gesetzt ist, entfaellt die WHERE-Erweiterung komplett.
    return collection.includeDlcs ? '' : 'AND $purchaseAlias.purchase_type = ?';
  }

  List<Object?> _automaticPurchaseTypeArgs(SteamCollection collection) {
    return collection.includeDlcs ? [] : [SteamPurchaseType.game.storageValue];
  }

  String _automaticPurchaseOrderBy(SteamCollectionSortMode sortMode) {
    return switch (sortMode) {
      SteamCollectionSortMode.releaseDateAsc => _releaseDateOrderBy(
        purchaseAlias: 'p',
        metadataAlias: 'm',
        descending: false,
      ),
      SteamCollectionSortMode.releaseDateDesc => _releaseDateOrderBy(
        purchaseAlias: 'p',
        metadataAlias: 'm',
        descending: true,
      ),
      SteamCollectionSortMode.manual => 'p.purchase_date DESC, p.id DESC',
    };
  }

  String _collectionItemOrderBy(SteamCollectionSortMode sortMode) {
    return switch (sortMode) {
      SteamCollectionSortMode.releaseDateAsc => _releaseDateOrderBy(
        purchaseAlias: 'p',
        metadataAlias: 'm',
        descending: false,
        fallback: 'ci.custom_order ASC, ci.created_at ASC, ci.id ASC',
      ),
      SteamCollectionSortMode.releaseDateDesc => _releaseDateOrderBy(
        purchaseAlias: 'p',
        metadataAlias: 'm',
        descending: true,
        fallback: 'ci.custom_order ASC, ci.created_at ASC, ci.id ASC',
      ),
      SteamCollectionSortMode.manual =>
        'ci.custom_order ASC, ci.created_at ASC, ci.id ASC',
    };
  }

  String _releaseDateOrderBy({
    required String purchaseAlias,
    required String metadataAlias,
    required bool descending,
    String? fallback,
  }) {
    // Eintraege ohne Release-Datum bleiben am Ende/Anfang der sortierten Gruppe
    // kontrolliert einsortierbar und fallen dann auf Kaufdatum/manuelle Ordnung
    // zurueck.
    final direction = descending ? 'DESC' : 'ASC';
    final fallbackOrder =
        fallback ?? '$purchaseAlias.purchase_date DESC, $purchaseAlias.id DESC';

    return '''
      $metadataAlias.release_date IS NULL ASC,
      $metadataAlias.release_date $direction,
      $fallbackOrder
    ''';
  }

  Future<int> _nextCustomOrder(
    DatabaseExecutor executor,
    int collectionId,
  ) async {
    // Neue Items werden hinter das bisher letzte Item gesetzt.
    final rows = await executor.rawQuery(
      '''
      SELECT COALESCE(MAX(custom_order) + 1, 0) AS next_order
      FROM $collectionItemsTable
      WHERE collection_id = ?
      ''',
      [collectionId],
    );

    return rows.single['next_order'] as int;
  }

  Future<Set<int>> _getManualCollectionIds(DatabaseExecutor executor) async {
    final rows = await executor.query(
      collectionsTable,
      columns: ['id'],
      where: 'collection_type = ?',
      whereArgs: [SteamCollectionType.manual.storageValue],
    );

    return rows.map((row) => row['id'] as int).toSet();
  }

  Future<bool> _isManualCollection(
    DatabaseExecutor executor,
    int collectionId,
  ) async {
    final rows = await executor.query(
      collectionsTable,
      columns: ['collection_type'],
      where: 'id = ?',
      whereArgs: [collectionId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return false;
    }

    return SteamCollectionType.fromStorage(rows.single['collection_type']) ==
        SteamCollectionType.manual;
  }
}
