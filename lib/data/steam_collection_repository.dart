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
      now: _now,
    );

    return db.insert(collectionItemsTable, item.toMap());
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
}
