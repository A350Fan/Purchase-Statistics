import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_collection_repository.dart';
import 'package:purchase_statistics/models/steam_collection.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SteamCollectionRepository repository;
  final now = DateTime.utc(2026, 5, 23, 12);

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createTestSchema(db);
        },
      ),
    );
    repository = SteamCollectionRepository(
      databaseProvider: () async => db,
      now: () => now,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SteamCollectionRepository', () {
    test('creates and updates collections', () async {
      final collectionId = await repository.insertCollection(
        SteamCollection(
          name: 'Favorites',
          description: 'Replay regularly',
          createdAt: now,
        ),
      );

      var collections = await repository.getCollections();

      expect(collections, hasLength(1));
      expect(collections.single.id, collectionId);
      expect(collections.single.name, 'Favorites');
      expect(collections.single.description, 'Replay regularly');
      expect(collections.single.sortMode, SteamCollection.manualSortMode);

      await repository.updateCollection(
        collections.single.copyWith(name: 'Backlog', description: null),
      );
      collections = await repository.getCollections();

      expect(collections.single.name, 'Backlog');
      expect(collections.single.description, isNull);
    });

    test('adds and removes purchases from a collection', () async {
      final purchaseId = await _insertPurchase(db, gameName: 'Portal 2');
      final collectionId = await repository.insertCollection(
        SteamCollection(name: 'Favorites', createdAt: now),
      );

      final itemId = await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: purchaseId,
      );
      final items = await repository.getItemsForCollection(collectionId);

      expect(items, hasLength(1));
      expect(items.single.id, itemId);
      expect(items.single.collectionId, collectionId);
      expect(items.single.purchaseId, purchaseId);
      expect(items.single.customOrder, 0);
      expect(items.single.createdAt, now);

      final removedCount = await repository.removePurchaseFromCollection(
        collectionId: collectionId,
        purchaseId: purchaseId,
      );

      expect(removedCount, 1);
      expect(await repository.getItemsForCollection(collectionId), isEmpty);
    });

    test('does not duplicate purchase assignments', () async {
      final purchaseId = await _insertPurchase(db, gameName: 'Portal');
      final collectionId = await repository.insertCollection(
        SteamCollection(name: 'Favorites', createdAt: now),
      );

      final firstItemId = await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: purchaseId,
      );
      final secondItemId = await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: purchaseId,
      );
      final items = await repository.getItemsForCollection(collectionId);

      expect(secondItemId, firstItemId);
      expect(items, hasLength(1));
    });

    test('schema rejects duplicate purchase assignments', () async {
      final purchaseId = await _insertPurchase(db, gameName: 'Portal');
      final collectionId = await repository.insertCollection(
        SteamCollection(name: 'Favorites', createdAt: now),
      );
      final item = {
        'collection_id': collectionId,
        'purchase_id': purchaseId,
        'custom_order': 0,
        'created_at': now.toIso8601String(),
      };

      await db.insert('collection_items', item);

      await expectLater(
        db.insert('collection_items', item),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('deleting a collection cascades to its items', () async {
      final purchaseId = await _insertPurchase(db, gameName: 'Half-Life');
      final collectionId = await repository.insertCollection(
        SteamCollection(name: 'Classics', createdAt: now),
      );
      await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: purchaseId,
      );

      await repository.deleteCollection(collectionId);

      expect(await repository.getCollections(), isEmpty);
      expect(await repository.getItemsForCollection(collectionId), isEmpty);
    });
  });
}

Future<void> _createTestSchema(Database db) async {
  await db.execute('''
    CREATE TABLE steam_purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_date TEXT NOT NULL,
      purchase_type TEXT NOT NULL DEFAULT 'game',
      game_name TEXT NOT NULL,
      edition TEXT,
      dlc_name TEXT,
      price REAL NOT NULL,
      original_price REAL,
      playtime_hours REAL,
      note TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE collections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      sort_mode TEXT NOT NULL DEFAULT 'manual',
      created_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE collection_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      collection_id INTEGER NOT NULL,
      purchase_id INTEGER NOT NULL,
      custom_order INTEGER NOT NULL DEFAULT 0,
      note TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(collection_id) REFERENCES collections(id) ON DELETE CASCADE,
      FOREIGN KEY(purchase_id) REFERENCES steam_purchases(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE UNIQUE INDEX idx_collection_items_unique_purchase
    ON collection_items(collection_id, purchase_id)
  ''');
}

Future<int> _insertPurchase(Database db, {required String gameName}) {
  return db.insert('steam_purchases', {
    'purchase_date': DateTime.utc(2026, 5, 1).toIso8601String(),
    'purchase_type': 'game',
    'game_name': gameName,
    'price': 9.99,
  });
}
