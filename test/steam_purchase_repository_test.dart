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
  });
}
