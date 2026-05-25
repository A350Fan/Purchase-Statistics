import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/settings/app_settings.dart';
import 'package:purchase_statistics/settings/settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late _MemoryAppSecretStore secretStore;
  late SettingsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await _createSettingsTable(db);
        },
      ),
    );
    secretStore = _MemoryAppSecretStore();
    repository = SettingsRepository(
      databaseProvider: () async => db,
      secretStore: secretStore,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('stores Steam Web API key in secret store instead of SQLite', () async {
    await repository.saveSettings(
      const AppSettings(
        steamAccountIdentifier: '76561198000000000',
        steamWebApiKey: ' test-api-key ',
      ),
    );

    final rows = await db.query('app_settings');
    final settings = await repository.loadSettings();

    expect(rows.single['steam_web_api_key'], isNull);
    expect(secretStore.steamWebApiKey, 'test-api-key');
    expect(settings.steamWebApiKey, 'test-api-key');
    expect(settings.steamAccountIdentifier, '76561198000000000');
  });

  test('migrates legacy SQLite Steam Web API key to secret store', () async {
    await db.insert('app_settings', {
      'id': 1,
      'theme_mode': AppThemeMode.dark.storageValue,
      'language': AppLanguage.german.storageValue,
      'currency': AppCurrency.eur.storageValue,
      'steam_account_identifier': 'profile-name',
      'steam_web_api_key': 'legacy-api-key',
      'steam_include_played_free_games': 1,
    });

    final settings = await repository.loadSettings();
    final rows = await db.query('app_settings');

    expect(settings.steamWebApiKey, 'legacy-api-key');
    expect(secretStore.steamWebApiKey, 'legacy-api-key');
    expect(rows.single['steam_web_api_key'], isNull);
  });

  test(
    'deletes Steam Web API key from secret store when saved empty',
    () async {
      secretStore.steamWebApiKey = 'old-api-key';

      await repository.saveSettings(const AppSettings(steamWebApiKey: ' '));

      final rows = await db.query('app_settings');

      expect(secretStore.steamWebApiKey, isNull);
      expect(rows.single['steam_web_api_key'], isNull);
    },
  );
}

class _MemoryAppSecretStore implements AppSecretStore {
  String? steamWebApiKey;

  @override
  Future<String?> readSteamWebApiKey() async {
    return steamWebApiKey;
  }

  @override
  Future<void> saveSteamWebApiKey(String? apiKey) async {
    final trimmedApiKey = apiKey?.trim();
    steamWebApiKey = trimmedApiKey == null || trimmedApiKey.isEmpty
        ? null
        : trimmedApiKey;
  }
}

Future<void> _createSettingsTable(Database db) async {
  await db.execute('''
    CREATE TABLE app_settings (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      theme_mode TEXT NOT NULL,
      language TEXT NOT NULL,
      currency TEXT NOT NULL DEFAULT 'eur',
      steam_account_identifier TEXT,
      steam_web_api_key TEXT,
      steam_include_played_free_games INTEGER NOT NULL DEFAULT 1
    )
  ''');
}
