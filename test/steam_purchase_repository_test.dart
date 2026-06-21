// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_purchase_repository.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SteamPurchaseRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE steam_purchases (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              purchase_date TEXT NOT NULL,
              purchase_type TEXT NOT NULL DEFAULT 'game',
              game_name TEXT NOT NULL,
              edition TEXT,
              dlc_name TEXT,
              game_status TEXT,
              steam_app_id INTEGER,
              price REAL NOT NULL,
              original_price REAL,
              playtime_hours REAL,
              main_story_hours REAL,
              main_extra_hours REAL,
              completionist_hours REAL,
              backlog_priority_snoozed_until TEXT,
              note TEXT
            )
          ''');
        },
      ),
    );
    repository = SteamPurchaseRepository(databaseProvider: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SteamPurchaseRepository', () {
    test('updates playtime for matching Steam app ids only', () async {
      await repository.addPurchases([
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          steamAppId: 620,
          price: 9.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 2),
          gameName: 'Stardew Valley',
          steamAppId: 413150,
          price: 4.99,
          playtimeHours: 1.5,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 3),
          gameName: 'Unlinked',
          price: 1.99,
        ),
      ]);

      final updatedCount = await repository.updatePlaytimeHoursBySteamAppId({
        620: 2.5,
        413150: 1.5,
        999999: 10,
      });
      final purchases = await repository.getAllPurchases();

      expect(updatedCount, 1);
      expect(
        purchases
            .singleWhere((purchase) => purchase.gameName == 'Portal 2')
            .playtimeHours,
        2.5,
      );
      expect(
        purchases
            .singleWhere((purchase) => purchase.gameName == 'Stardew Valley')
            .playtimeHours,
        1.5,
      );
      expect(
        purchases
            .singleWhere((purchase) => purchase.gameName == 'Unlinked')
            .playtimeHours,
        isNull,
      );
    });

    test('skips duplicate imports that only differ in synced fields', () async {
      await repository.addPurchase(
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.completed,
          steamAppId: 620,
          price: 9.99,
          playtimeHours: 12,
          mainStoryHours: 8,
          note: 'local note',
        ),
      );

      final result = await repository.importPurchases([
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: '  portal   2  ',
          gameStatus: SteamGameStatus.open,
          price: 9.99,
          playtimeHours: 100,
          mainStoryHours: 20,
          note: 'csv note',
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 2),
          gameName: 'Hades',
          price: 19.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 2),
          gameName: 'HADES',
          price: 19.99,
          playtimeHours: 2,
        ),
      ]);
      final purchases = await repository.getAllPurchases();

      expect(result.importedCount, 1);
      expect(result.skippedDuplicateCount, 2);
      expect(result.totalCount, 3);
      expect(result.importedPurchases.single.gameName, 'Hades');
      expect(purchases, hasLength(2));
      expect(
        purchases.singleWhere((purchase) => purchase.gameName == 'Portal 2'),
        isA<SteamPurchase>()
            .having((purchase) => purchase.playtimeHours, 'playtime', 12)
            .having(
              (purchase) => purchase.gameStatus,
              'status',
              SteamGameStatus.completed,
            )
            .having((purchase) => purchase.note, 'note', 'local note'),
      );
      expect(
        purchases.singleWhere((purchase) => purchase.gameName == 'Hades').price,
        19.99,
      );
    });

    test('persists backlog priority snooze changes', () async {
      final purchase = await repository.addPurchase(
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.open,
          price: 9.99,
        ),
      );
      final snoozedUntil = DateTime(2026, 6, 7);

      await repository.updatePurchase(
        purchase.copyWith(backlogPrioritySnoozedUntil: snoozedUntil),
      );
      final snoozedPurchase = (await repository.getAllPurchases()).single;

      expect(snoozedPurchase.backlogPrioritySnoozedUntil, snoozedUntil);

      await repository.updatePurchase(
        snoozedPurchase.copyWith(backlogPrioritySnoozedUntil: null),
      );
      final restoredPurchase = (await repository.getAllPurchases()).single;

      expect(restoredPurchase.backlogPrioritySnoozedUntil, isNull);
    });
  });
}
