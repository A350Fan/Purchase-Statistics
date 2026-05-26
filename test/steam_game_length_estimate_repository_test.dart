import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_game_length_estimate_repository.dart';
import 'package:purchase_statistics/models/steam_game_length_estimate.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SteamGameLengthEstimateRepository repository;

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
            CREATE TABLE steam_game_length_estimates (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              game_name TEXT NOT NULL,
              normalized_game_name TEXT NOT NULL,
              steam_app_id INTEGER,
              main_story_hours REAL,
              main_extra_hours REAL,
              completionist_hours REAL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_length_estimates_normalized_name
            ON steam_game_length_estimates(normalized_game_name)
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX idx_length_estimates_steam_app_id
            ON steam_game_length_estimates(steam_app_id)
            WHERE steam_app_id IS NOT NULL
          ''');
        },
      ),
    );
    repository = SteamGameLengthEstimateRepository(
      databaseProvider: () async => db,
      now: () => DateTime(2026, 5, 26),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SteamGameLengthEstimateRepository', () {
    test('stores estimates without creating purchases', () async {
      final count = await repository.upsertEstimates([
        const SteamGameLengthEstimate(
          gameName: 'Portal 2',
          steamAppId: 620,
          mainStoryHours: 8,
          mainExtraHours: 10.5,
          completionistHours: 14,
        ),
      ]);

      final estimates = await repository.getAllEstimates();
      final purchaseTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'steam_purchases'",
      );

      expect(count, 1);
      expect(estimates, hasLength(1));
      expect(estimates.single.gameName, 'Portal 2');
      expect(purchaseTables, isEmpty);
    });

    test('finds estimates by Steam app id or normalized game name', () async {
      await repository.upsertEstimates([
        const SteamGameLengthEstimate(
          gameName: 'Train Sim World\u00ae 2',
          steamAppId: 1282590,
          mainStoryHours: 20,
        ),
      ]);

      final byAppId = await repository.findEstimate(steamAppId: 1282590);
      final byName = await repository.findEstimate(
        gameName: 'Train Sim World 2',
      );

      expect(byAppId?.mainStoryHours, 20);
      expect(byName?.steamAppId, 1282590);
    });

    test(
      'syncs game purchase estimates into the background database',
      () async {
        await repository.upsertPurchases([
          SteamPurchase(
            purchaseDate: DateTime(2026, 5, 1),
            gameName: 'Portal 2',
            price: 9.99,
            mainStoryHours: 8,
          ),
          SteamPurchase(
            purchaseDate: DateTime(2026, 5, 2),
            purchaseType: SteamPurchaseType.dlc,
            gameName: 'Portal 2',
            dlcName: 'Soundtrack',
            price: 1.99,
            mainStoryHours: 2,
          ),
        ]);

        final estimates = await repository.getAllEstimates();

        expect(estimates, hasLength(1));
        expect(estimates.single.gameName, 'Portal 2');
        expect(estimates.single.mainStoryHours, 8);
      },
    );
  });
}
