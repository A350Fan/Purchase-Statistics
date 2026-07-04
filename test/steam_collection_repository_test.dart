// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_collection_repository.dart';
import 'package:purchase_statistics/models/steam_collection.dart';
import 'package:purchase_statistics/models/steam_game_metadata.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
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
      expect(collections.single.collectionType, SteamCollectionType.manual);

      await repository.updateCollection(
        collections.single.copyWith(name: 'Backlog', description: null),
      );
      collections = await repository.getCollections();

      expect(collections.single.name, 'Backlog');
      expect(collections.single.description, isNull);
    });

    test('creates automatic collections with metadata rules', () async {
      final collectionId = await repository.insertCollection(
        SteamCollection(
          name: 'Puzzle',
          description: 'Steam genre',
          collectionType: SteamCollectionType.automatic,
          ruleField: SteamCollectionRuleField.genre,
          ruleValue: 'Puzzle',
          includeDlcs: true,
          createdAt: now,
        ),
      );

      final collections = await repository.getCollections();

      expect(collections.single.id, collectionId);
      expect(collections.single.collectionType, SteamCollectionType.automatic);
      expect(collections.single.ruleField, SteamCollectionRuleField.genre);
      expect(collections.single.ruleValue, 'Puzzle');
      expect(collections.single.includeDlcs, true);
      expect(collections.single.metadataRule, isNotNull);
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

    test('counts items by collection', () async {
      final firstPurchaseId = await _insertPurchase(db, gameName: 'Portal');
      final secondPurchaseId = await _insertPurchase(db, gameName: 'Half-Life');
      final firstCollectionId = await repository.insertCollection(
        SteamCollection(name: 'Favorites', createdAt: now),
      );
      final secondCollectionId = await repository.insertCollection(
        SteamCollection(name: 'Backlog', createdAt: now),
      );

      await repository.addPurchaseToCollection(
        collectionId: firstCollectionId,
        purchaseId: firstPurchaseId,
      );
      await repository.addPurchaseToCollection(
        collectionId: firstCollectionId,
        purchaseId: secondPurchaseId,
      );
      await repository.addPurchaseToCollection(
        collectionId: secondCollectionId,
        purchaseId: secondPurchaseId,
      );

      final counts = await repository.getItemCountsByCollection();

      expect(counts[firstCollectionId], 2);
      expect(counts[secondCollectionId], 1);
    });

    test('loads purchases for automatic collection rules', () async {
      final portalId = await _insertPurchase(
        db,
        gameName: 'Portal 2',
        steamAppId: 620,
      );
      await _insertPurchase(db, gameName: 'Half-Life', steamAppId: 70);
      await _insertMetadataValues(
        db,
        steamAppId: 620,
        values: {
          SteamMetadataField.genre: ['Puzzle', 'Action'],
        },
      );
      await _insertMetadataValues(
        db,
        steamAppId: 70,
        values: {
          SteamMetadataField.genre: ['Action'],
        },
      );
      final collection = SteamCollection(
        name: 'Puzzle',
        collectionType: SteamCollectionType.automatic,
        ruleField: SteamCollectionRuleField.genre,
        ruleValue: 'puzzle',
        createdAt: now,
      );

      final purchases = await repository.getPurchasesForAutomaticCollection(
        collection,
      );
      final count = await repository.countPurchasesForAutomaticCollection(
        collection,
      );

      expect(purchases, hasLength(1));
      expect(purchases.single.id, portalId);
      expect(purchases.single.gameName, 'Portal 2');
      expect(count, 1);
    });

    test('loads purchases for title contains rules', () async {
      final firstId = await _insertPurchase(
        db,
        gameName: "Assassin's Creed II",
      );
      final secondId = await _insertPurchase(
        db,
        gameName: "Assassin's Creed Odyssey",
      );
      await _insertPurchase(db, gameName: 'Far Cry 5');
      final collection = SteamCollection(
        name: "Assassin's Creed",
        collectionType: SteamCollectionType.automatic,
        ruleField: SteamCollectionRuleField.titleContains,
        ruleValue: "assassin's creed",
        createdAt: now,
      );

      final purchases = await repository.getPurchasesForAutomaticCollection(
        collection,
      );
      final count = await repository.countPurchasesForAutomaticCollection(
        collection,
      );

      expect(purchases.map((purchase) => purchase.id).toSet(), {
        firstId,
        secondId,
      });
      expect(count, 2);
    });

    test('automatic collections include dlcs only when enabled', () async {
      final gameId = await _insertPurchase(db, gameName: 'Portal 2');
      final dlcId = await _insertPurchase(
        db,
        gameName: 'Portal 2',
        purchaseType: SteamPurchaseType.dlc,
        dlcName: 'Soundtrack',
      );
      final collection = SteamCollection(
        name: 'Portal',
        collectionType: SteamCollectionType.automatic,
        ruleField: SteamCollectionRuleField.titleContains,
        ruleValue: 'portal',
        createdAt: now,
      );

      final gameOnlyPurchases = await repository
          .getPurchasesForAutomaticCollection(collection);
      final gameOnlyCount = await repository
          .countPurchasesForAutomaticCollection(collection);
      final purchasesWithDlcs = await repository
          .getPurchasesForAutomaticCollection(
            collection.copyWith(includeDlcs: true),
          );
      final countWithDlcs = await repository
          .countPurchasesForAutomaticCollection(
            collection.copyWith(includeDlcs: true),
          );

      expect(gameOnlyPurchases.map((purchase) => purchase.id), [gameId]);
      expect(gameOnlyCount, 1);
      expect(purchasesWithDlcs.map((purchase) => purchase.id).toSet(), {
        gameId,
        dlcId,
      });
      expect(countWithDlcs, 2);
    });

    test('sorts automatic collection purchases by release date', () async {
      final firstId = await _insertPurchase(
        db,
        gameName: "Assassin's Creed",
        steamAppId: 15100,
      );
      final secondId = await _insertPurchase(
        db,
        gameName: "Assassin's Creed II",
        steamAppId: 33230,
      );
      final thirdId = await _insertPurchase(
        db,
        gameName: "Assassin's Creed Odyssey",
        steamAppId: 812140,
      );
      await _insertMetadataValues(
        db,
        steamAppId: 15100,
        releaseDate: DateTime.utc(2008, 4, 9),
        values: const <SteamMetadataField, List<String>>{},
      );
      await _insertMetadataValues(
        db,
        steamAppId: 33230,
        releaseDate: DateTime.utc(2010, 3, 4),
        values: const <SteamMetadataField, List<String>>{},
      );
      await _insertMetadataValues(
        db,
        steamAppId: 812140,
        releaseDate: DateTime.utc(2018, 10, 5),
        values: const <SteamMetadataField, List<String>>{},
      );
      final collection = SteamCollection(
        name: "Assassin's Creed",
        sortMode: SteamCollectionSortMode.releaseDateAsc,
        collectionType: SteamCollectionType.automatic,
        ruleField: SteamCollectionRuleField.titleContains,
        ruleValue: "assassin's creed",
        createdAt: now,
      );

      final purchases = await repository.getPurchasesForAutomaticCollection(
        collection,
      );

      expect(purchases.map((purchase) => purchase.id), [
        firstId,
        secondId,
        thirdId,
      ]);
    });

    test('loads available metadata values for collection rules', () async {
      await _insertMetadataValues(
        db,
        steamAppId: 620,
        values: {
          SteamMetadataField.genre: ['Puzzle', 'Action'],
          SteamMetadataField.developer: ['Valve'],
        },
      );
      await _insertMetadataValues(
        db,
        steamAppId: 70,
        values: {
          SteamMetadataField.genre: ['Action'],
          SteamMetadataField.developer: ['Valve'],
        },
      );

      final genres = await repository.getAvailableMetadataRuleValues(
        SteamMetadataField.genre,
      );
      final developers = await repository.getAvailableMetadataRuleValues(
        SteamMetadataField.developer,
      );

      expect(genres, ['Action', 'Puzzle']);
      expect(developers, ['Valve']);
    });

    test('replaces collection assignments for a purchase', () async {
      final purchaseId = await _insertPurchase(db, gameName: 'Portal');
      final firstCollectionId = await repository.insertCollection(
        SteamCollection(name: 'Favorites', createdAt: now),
      );
      final secondCollectionId = await repository.insertCollection(
        SteamCollection(name: 'Backlog', createdAt: now),
      );

      await repository.replaceCollectionsForPurchase(
        purchaseId: purchaseId,
        collectionIds: {firstCollectionId},
      );
      expect(await repository.getCollectionIdsForPurchase(purchaseId), {
        firstCollectionId,
      });

      await repository.replaceCollectionsForPurchase(
        purchaseId: purchaseId,
        collectionIds: {secondCollectionId},
      );

      expect(await repository.getCollectionIdsForPurchase(purchaseId), {
        secondCollectionId,
      });
      expect(
        await repository.getItemsForCollection(firstCollectionId),
        isEmpty,
      );
    });

    test('updates manual item order', () async {
      final firstPurchaseId = await _insertPurchase(db, gameName: 'Portal');
      final secondPurchaseId = await _insertPurchase(db, gameName: 'Half-Life');
      final collectionId = await repository.insertCollection(
        SteamCollection(name: 'Favorites', createdAt: now),
      );
      await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: firstPurchaseId,
      );
      await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: secondPurchaseId,
      );
      final initialItems = await repository.getItemsForCollection(collectionId);

      await repository.updateCollectionItemOrder(
        collectionId: collectionId,
        itemIds: [initialItems.last.id!, initialItems.first.id!],
      );
      final reorderedItems = await repository.getItemsForCollection(
        collectionId,
      );

      expect(reorderedItems.first.purchaseId, secondPurchaseId);
      expect(reorderedItems.last.purchaseId, firstPurchaseId);
      expect(reorderedItems.first.customOrder, 0);
      expect(reorderedItems.last.customOrder, 1);
    });

    test('sorts manual collection items by release date', () async {
      final olderPurchaseId = await _insertPurchase(
        db,
        gameName: 'Older Game',
        steamAppId: 1,
      );
      final newerPurchaseId = await _insertPurchase(
        db,
        gameName: 'Newer Game',
        steamAppId: 2,
      );
      final collectionId = await repository.insertCollection(
        SteamCollection(name: 'Timeline', createdAt: now),
      );
      await _insertMetadataValues(
        db,
        steamAppId: 1,
        releaseDate: DateTime.utc(2010, 1, 1),
        values: const <SteamMetadataField, List<String>>{},
      );
      await _insertMetadataValues(
        db,
        steamAppId: 2,
        releaseDate: DateTime.utc(2020, 1, 1),
        values: const <SteamMetadataField, List<String>>{},
      );
      await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: newerPurchaseId,
      );
      await repository.addPurchaseToCollection(
        collectionId: collectionId,
        purchaseId: olderPurchaseId,
      );

      final items = await repository.getItemsForCollection(
        collectionId,
        sortMode: SteamCollectionSortMode.releaseDateAsc,
      );

      expect(items.first.purchaseId, olderPurchaseId);
      expect(items.last.purchaseId, newerPurchaseId);
    });

    test('loads release metadata by purchase id', () async {
      final purchaseWithMetadataId = await _insertPurchase(
        db,
        gameName: 'Portal 2',
        steamAppId: 620,
      );
      final purchaseWithoutMetadataId = await _insertPurchase(
        db,
        gameName: 'Half-Life',
        steamAppId: 70,
      );
      await _insertMetadataValues(
        db,
        steamAppId: 620,
        releaseDate: DateTime.utc(2011, 4, 18),
        releaseDateText: 'Apr 18, 2011',
        values: const <SteamMetadataField, List<String>>{},
      );

      final metadataByPurchaseId = await repository.getPurchaseMetadataByIds([
        purchaseWithMetadataId,
        purchaseWithoutMetadataId,
        purchaseWithMetadataId,
      ]);

      expect(
        metadataByPurchaseId[purchaseWithMetadataId]?.releaseDate,
        DateTime.utc(2011, 4, 18),
      );
      expect(
        metadataByPurchaseId[purchaseWithMetadataId]?.releaseDateText,
        'Apr 18, 2011',
      );
      expect(
        metadataByPurchaseId.containsKey(purchaseWithoutMetadataId),
        false,
      );
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

    test('rejects manual assignments to automatic collections', () async {
      final purchaseId = await _insertPurchase(db, gameName: 'Portal');
      final collectionId = await repository.insertCollection(
        SteamCollection(
          name: 'Puzzle',
          collectionType: SteamCollectionType.automatic,
          ruleField: SteamCollectionRuleField.genre,
          ruleValue: 'Puzzle',
          createdAt: now,
        ),
      );

      await expectLater(
        repository.addPurchaseToCollection(
          collectionId: collectionId,
          purchaseId: purchaseId,
        ),
        throwsArgumentError,
      );
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
      launcher TEXT NOT NULL DEFAULT 'steam',
      game_name TEXT NOT NULL,
      edition TEXT,
      dlc_name TEXT,
      game_status TEXT,
      steam_app_id INTEGER,
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
      collection_type TEXT NOT NULL DEFAULT 'manual',
      rule_field TEXT,
      rule_value TEXT,
      include_dlcs INTEGER NOT NULL DEFAULT 0,
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

  await db.execute('''
    CREATE TABLE steam_game_metadata (
      steam_app_id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      release_date TEXT,
      release_date_text TEXT,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE steam_game_metadata_values (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      steam_app_id INTEGER NOT NULL,
      field TEXT NOT NULL,
      value TEXT NOT NULL,
      FOREIGN KEY(steam_app_id)
        REFERENCES steam_game_metadata(steam_app_id)
        ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE UNIQUE INDEX idx_steam_metadata_values_unique
    ON steam_game_metadata_values(steam_app_id, field, value)
  ''');
}

Future<int> _insertPurchase(
  Database db, {
  required String gameName,
  int? steamAppId,
  SteamPurchaseType purchaseType = SteamPurchaseType.game,
  String? dlcName,
}) {
  return db.insert('steam_purchases', {
    'purchase_date': DateTime.utc(2026, 5, 1).toIso8601String(),
    'purchase_type': purchaseType.storageValue,
    'launcher': PurchaseLauncher.steam.storageValue,
    'game_name': gameName,
    'dlc_name': dlcName,
    'steam_app_id': steamAppId,
    'price': 9.99,
  });
}

Future<void> _insertMetadataValues(
  Database db, {
  required int steamAppId,
  DateTime? releaseDate,
  String? releaseDateText,
  required Map<SteamMetadataField, List<String>> values,
}) async {
  await db.insert('steam_game_metadata', {
    'steam_app_id': steamAppId,
    'name': 'App $steamAppId',
    'release_date': releaseDate?.toIso8601String(),
    'release_date_text': releaseDateText,
    'updated_at': DateTime.utc(2026, 5, 23).toIso8601String(),
  });

  for (final entry in values.entries) {
    for (final value in entry.value) {
      await db.insert('steam_game_metadata_values', {
        'steam_app_id': steamAppId,
        'field': entry.key.storageValue,
        'value': value,
      });
    }
  }
}
