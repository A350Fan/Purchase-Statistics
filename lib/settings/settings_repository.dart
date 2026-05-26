import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import 'app_settings.dart';

/// Abstraktion fuer den persistenten Settings-Speicher.
///
/// Tests koennen diese Schnittstelle mit In-Memory-Speichern ersetzen.
abstract class AppSettingsStore {
  Future<AppSettings> loadSettings();

  Future<void> saveSettings(AppSettings settings);
}

/// Separater Speicher fuer Geheimnisse.
///
/// Der Steam-Web-API-Key soll nicht mehr dauerhaft in der normalen SQLite-Zeile
/// liegen, sondern im plattformspezifischen Secure Storage.
abstract class AppSecretStore {
  Future<String?> readSteamWebApiKey();

  Future<void> saveSteamWebApiKey(String? apiKey);
}

/// Secure-Storage-Implementierung fuer den Steam-Web-API-Key.
class SecureAppSecretStore implements AppSecretStore {
  static const String _steamWebApiKeyKey = 'steam_web_api_key';

  final FlutterSecureStorage _storage;

  SecureAppSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readSteamWebApiKey() async {
    return _nullableString(await _storage.read(key: _steamWebApiKeyKey));
  }

  @override
  Future<void> saveSteamWebApiKey(String? apiKey) async {
    final normalizedApiKey = _nullableString(apiKey);

    // Leere Werte bedeuten "Key entfernen" und halten den Secure Storage
    // sauber, statt leere Strings zu persistieren.
    if (normalizedApiKey == null) {
      await _storage.delete(key: _steamWebApiKeyKey);
      return;
    }

    await _storage.write(key: _steamWebApiKeyKey, value: normalizedApiKey);
  }

  static String? _nullableString(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}

/// SQLite-Repository fuer normale App-Einstellungen.
///
/// Es liest/schreibt die sichtbaren Einstellungen aus `app_settings` und
/// migriert alte API-Keys in den sicheren Speicher, falls sie noch in der
/// Datenbank liegen.
class SettingsRepository implements AppSettingsStore {
  static const String _tableName = 'app_settings';
  static const int _settingsId = 1;

  final Future<Database> Function() _databaseProvider;
  final AppSecretStore _secretStore;

  SettingsRepository({
    Future<Database> Function()? databaseProvider,
    AppSecretStore? secretStore,
  }) : _databaseProvider = databaseProvider ?? (() => AppDatabase.instance),
       _secretStore = secretStore ?? SecureAppSecretStore();

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
    final legacySteamWebApiKey = _nullableString(row['steam_web_api_key']);
    // Fruehere Versionen speicherten den Key in SQLite. Beim Laden wird er, wenn
    // moeglich, in den Secure Storage verschoben und danach aus SQLite entfernt.
    final steamWebApiKey = await _resolveSteamWebApiKey(
      db,
      legacySteamWebApiKey,
    );

    return AppSettings(
      themeMode: AppThemeMode.fromStorage(row['theme_mode']),
      language: AppLanguage.fromStorage(row['language']),
      currency: AppCurrency.fromStorage(row['currency']),
      steamAccountIdentifier: _nullableString(row['steam_account_identifier']),
      steamWebApiKey: steamWebApiKey,
      steamIncludePlayedFreeGames: row['steam_include_played_free_games'] != 0,
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final db = await _databaseProvider();
    await _secretStore.saveSteamWebApiKey(
      _nullableStorageString(settings.steamWebApiKey),
    );

    await db.insert(_tableName, {
      'id': _settingsId,
      'theme_mode': settings.themeMode.storageValue,
      'language': settings.language.storageValue,
      'currency': settings.currency.storageValue,
      'steam_account_identifier': _nullableStorageString(
        settings.steamAccountIdentifier,
      ),
      'steam_web_api_key': null,
      'steam_include_played_free_games': settings.steamIncludePlayedFreeGames
          ? 1
          : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> _resolveSteamWebApiKey(
    Database db,
    String? legacySteamWebApiKey,
  ) async {
    final secureSteamWebApiKey = await _readSecureSteamWebApiKey();

    // Secure Storage hat Vorrang. Ein eventuell noch vorhandener Legacy-Wert
    // wird nur bereinigt.
    if (secureSteamWebApiKey != null) {
      if (legacySteamWebApiKey != null) {
        await _clearLegacySteamWebApiKey(db);
      }

      return secureSteamWebApiKey;
    }

    if (legacySteamWebApiKey == null) {
      return null;
    }

    // Migration: alten SQLite-Wert in Secure Storage schreiben. Wenn das
    // fehlschlaegt, wird aus Sicherheitsgruenden kein Key zurueckgegeben.
    try {
      await _secretStore.saveSteamWebApiKey(legacySteamWebApiKey);

      return legacySteamWebApiKey;
    } catch (_) {
      return null;
    } finally {
      await _clearLegacySteamWebApiKey(db);
    }
  }

  Future<String?> _readSecureSteamWebApiKey() async {
    try {
      return _nullableString(await _secretStore.readSteamWebApiKey());
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearLegacySteamWebApiKey(Database db) async {
    await db.update(
      _tableName,
      {'steam_web_api_key': null},
      where: 'id = ?',
      whereArgs: [_settingsId],
    );
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
