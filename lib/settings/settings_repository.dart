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

  final Future<Database> Function() _databaseProvider;

  SettingsRepository({Future<Database> Function()? databaseProvider})
    : _databaseProvider = databaseProvider ?? (() => AppDatabase.instance);

  @override
  Future<AppSettings> loadSettings() async {
    final db = await _databaseProvider();
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
      currency: AppCurrency.fromStorage(row['currency']),
      steamAccountIdentifier: _nullableString(row['steam_account_identifier']),
      steamWebApiKey: _nullableString(row['steam_web_api_key']),
      steamIncludePlayedFreeGames: row['steam_include_played_free_games'] != 0,
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final db = await _databaseProvider();

    await db.insert(_tableName, {
      'id': _settingsId,
      'theme_mode': settings.themeMode.storageValue,
      'language': settings.language.storageValue,
      'currency': settings.currency.storageValue,
      'steam_account_identifier': _nullableStorageString(
        settings.steamAccountIdentifier,
      ),
      'steam_web_api_key': _nullableStorageString(settings.steamWebApiKey),
      'steam_include_played_free_games': settings.steamIncludePlayedFreeGames
          ? 1
          : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  String? _nullableStorageString(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}
