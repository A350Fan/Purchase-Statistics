import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import 'app_settings.dart';

abstract class AppSettingsStore {
  Future<AppSettings> loadSettings();

  Future<void> saveSettings(AppSettings settings);
}

class SettingsRepository implements AppSettingsStore {
  static const String _tableName = 'app_settings';
  static const int _settingsId = 1;

  @override
  Future<AppSettings> loadSettings() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [_settingsId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return const AppSettings();
    }

    final row = rows.single;

    return AppSettings(
      themeMode: AppThemeMode.fromStorage(row['theme_mode']),
      language: AppLanguage.fromStorage(row['language']),
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final db = await AppDatabase.instance;

    await db.insert(_tableName, {
      'id': _settingsId,
      'theme_mode': settings.themeMode.storageValue,
      'language': settings.language.storageValue,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
