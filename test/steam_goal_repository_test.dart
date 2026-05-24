import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_goal_repository.dart';
import 'package:purchase_statistics/models/steam_goal_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SteamGoalRepository repository;

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
            CREATE TABLE steam_goals (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              annual_spending_limit REAL,
              backlog_limit INTEGER,
              unplayed_backlog_limit INTEGER,
              unplayed_backlog_value_limit REAL,
              completion_rate_target REAL
            )
          ''');
        },
      ),
    );
    repository = SteamGoalRepository(databaseProvider: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SteamGoalRepository', () {
    test('returns empty goals when no row exists', () async {
      final goals = await repository.loadGoals();

      expect(goals.hasAnyGoal, false);
    });

    test('saves and replaces goal settings', () async {
      await repository.saveGoals(
        const SteamGoalSettings(
          annualSpendingLimit: 400,
          backlogLimit: 30,
          unplayedBacklogLimit: 10,
          unplayedBacklogValueLimit: 120,
          completionRateTarget: 0.6,
        ),
      );

      var goals = await repository.loadGoals();

      expect(goals.annualSpendingLimit, 400);
      expect(goals.backlogLimit, 30);
      expect(goals.unplayedBacklogLimit, 10);
      expect(goals.unplayedBacklogValueLimit, 120);
      expect(goals.completionRateTarget, 0.6);

      await repository.saveGoals(const SteamGoalSettings(backlogLimit: 20));
      goals = await repository.loadGoals();

      expect(goals.annualSpendingLimit, isNull);
      expect(goals.backlogLimit, 20);
      expect(goals.unplayedBacklogLimit, isNull);
      expect(goals.unplayedBacklogValueLimit, isNull);
      expect(goals.completionRateTarget, isNull);
    });
  });
}
