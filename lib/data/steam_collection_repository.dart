import 'package:sqflite/sqflite.dart';

import '../models/collection_item.dart';
import '../models/steam_collection.dart';
import 'app_database.dart';

class SteamCollectionRepository {
  static const String collectionsTable = 'collections';
  static const String collectionItemsTable = 'collection_items';

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
    final rows = await db.rawQuery('''
      SELECT collection_id, COUNT(*) AS item_count
      FROM $collectionItemsTable
      GROUP BY collection_id
    ''');

    return {
      for (final row in rows)
        row['collection_id'] as int: (row['item_count'] as int?) ?? 0,
    };
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
    final maps = await db.query(
      collectionItemsTable,
      columns: ['collection_id'],
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );

    return maps.map((map) => map['collection_id'] as int).toSet();
  }

  Future<void> replaceCollectionsForPurchase({
    required int purchaseId,
    required Set<int> collectionIds,
  }) async {
    final db = await _databaseProvider();

    await db.transaction((transaction) async {
      final existingRows = await transaction.query(
        collectionItemsTable,
        columns: ['collection_id'],
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
      final existingCollectionIds = existingRows
          .map((row) => row['collection_id'] as int)
          .toSet();
      final collectionIdsToRemove = existingCollectionIds.difference(
        collectionIds,
      );
      final collectionIdsToAdd = collectionIds.difference(
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
}
