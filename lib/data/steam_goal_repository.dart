import 'package:sqflite/sqflite.dart';

import '../models/steam_goal_settings.dart';
import 'app_database.dart';

/// Speicher-Schnittstelle fuer Ziele.
abstract class SteamGoalStore {
  Future<SteamGoalSettings> loadGoals();

  Future<void> saveGoals(SteamGoalSettings goals);
}

/// SQLite-Implementierung fuer die Ziel-Einstellungen.
///
/// Wie bei den App-Settings gibt es genau eine Zeile mit ID 1.
class SteamGoalRepository implements SteamGoalStore {
  static const String _tableName = 'steam_goals';
  static const int _goalsId = 1;

  final Future<Database> Function() _databaseProvider;

  SteamGoalRepository({Future<Database> Function()? databaseProvider})
    : _databaseProvider = databaseProvider ?? (() => AppDatabase.instance);

  @override
  Future<SteamGoalSettings> loadGoals() async {
    final db = await _databaseProvider();
    final rows = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [_goalsId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return const SteamGoalSettings();
    }

    return SteamGoalSettings.fromMap(rows.single);
  }

  @override
  Future<void> saveGoals(SteamGoalSettings goals) async {
    final db = await _databaseProvider();

    await db.insert(
      _tableName,
      goals.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
