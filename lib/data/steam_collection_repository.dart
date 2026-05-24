import 'package:sqflite/sqflite.dart';

import '../models/collection_item.dart';
import '../models/steam_collection.dart';
import '../models/steam_game_metadata.dart';
import '../models/steam_purchase.dart';
import 'app_database.dart';

class SteamCollectionRepository {
  static const String collectionsTable = 'collections';
  static const String collectionItemsTable = 'collection_items';
  static const String _purchasesTable = 'steam_purchases';
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
    final rule = collection.metadataRule;

    if (rule == null) {
      return 0;
    }

    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT p.id) AS item_count
      FROM $_purchasesTable p
      INNER JOIN $_metadataValuesTable mv
        ON mv.steam_app_id = p.steam_app_id
      WHERE mv.field = ?
        AND LOWER(TRIM(mv.value)) = LOWER(TRIM(?))
      ''',
      [rule.field.storageValue, rule.value],
    );

    return (rows.single['item_count'] as int?) ?? 0;
  }

  Future<List<SteamPurchase>> getPurchasesForAutomaticCollection(
    SteamCollection collection,
  ) async {
    final rule = collection.metadataRule;

    if (rule == null) {
      return [];
    }

    final db = await _databaseProvider();
    final maps = await db.rawQuery(
      '''
      SELECT DISTINCT p.*
      FROM $_purchasesTable p
      INNER JOIN $_metadataValuesTable mv
        ON mv.steam_app_id = p.steam_app_id
      WHERE mv.field = ?
        AND LOWER(TRIM(mv.value)) = LOWER(TRIM(?))
      ORDER BY p.purchase_date DESC, p.id DESC
      ''',
      [rule.field.storageValue, rule.value],
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

  Future<List<CollectionItem>> getItemsForCollection(int collectionId) async {
    final db = await _databaseProvider();
    final maps = await db.query(
      collectionItemsTable,
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'custom_order ASC, created_at ASC, id ASC',
    );

    return maps.map(CollectionItem.fromMap).toList();
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

  Future<int> _nextCustomOrder(
    DatabaseExecutor executor,
    int collectionId,
  ) async {
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
