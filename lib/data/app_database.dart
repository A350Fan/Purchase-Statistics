// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'steam_store_search_text.dart';

/// Zentrale SQLite-Datenbank der App.
///
/// Diese Klasse kapselt Oeffnen, Plattformpfade, Schema-Erstellung und alle
/// Migrationen. Repositories holen sich ueber `AppDatabase.instance` dieselbe
/// Datenbankinstanz.
class AppDatabase {
  static Database? _database;
  static bool _isDesktopFactoryConfigured = false;

  /// Lazy Singleton: die Datenbank wird erst beim ersten Zugriff geoeffnet.
  static Future<Database> get instance async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  static Future<Database> _openDatabase() async {
    // Auf Desktop-Plattformen nutzt sqflite die FFI-Implementierung; mobile
    // Plattformen verwenden die normale sqflite-Factory.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _configureDesktopFactory();
    }

    final path = await _databaseFilePath();

    return openDatabase(
      path,
      // Jede Schema-Aenderung muss die Version erhoehen und unten in
      // `_upgradeDatabase` eine idempotente Migration ergaenzen.
      version: 20,
      onConfigure: _configureDatabase,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  static void _configureDesktopFactory() {
    if (_isDesktopFactoryConfigured) {
      return;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _isDesktopFactoryConfigured = true;
  }

  static Future<String> _databaseFilePath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _desktopDatabaseFilePath();
    }

    final databasePath = await getDatabasesPath();
    return join(databasePath, 'steam_stats.db');
  }

  static Future<String> _desktopDatabaseFilePath() async {
    final databaseDirectory = _desktopDatabaseDirectory();
    await databaseDirectory.create(recursive: true);

    final databasePath = join(databaseDirectory.path, 'steam_stats.db');
    await _migrateLegacyDesktopDatabase(databasePath);

    return databasePath;
  }

  static Directory _desktopDatabaseDirectory() {
    final environment = Platform.environment;

    // Windows: bevorzugt Roaming AppData, mit USERPROFILE als Fallback.
    if (Platform.isWindows) {
      final appData = environment['APPDATA']?.trim();

      if (appData != null && appData.isNotEmpty) {
        return Directory(join(appData, 'PurchaseStatistics'));
      }

      final userProfile = environment['USERPROFILE']?.trim();

      if (userProfile != null && userProfile.isNotEmpty) {
        return Directory(
          join(userProfile, 'AppData', 'Roaming', 'PurchaseStatistics'),
        );
      }
    }

    // macOS-Konvention fuer App-Support-Daten.
    if (Platform.isMacOS) {
      final home = environment['HOME']?.trim();

      if (home != null && home.isNotEmpty) {
        return Directory(
          join(home, 'Library', 'Application Support', 'PurchaseStatistics'),
        );
      }
    }

    // Linux/andere Desktop-Systeme folgen XDG, ansonsten wird ein lokaler
    // Fallback im Home-Verzeichnis verwendet.
    final xdgDataHome = environment['XDG_DATA_HOME']?.trim();

    if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
      return Directory(join(xdgDataHome, 'purchase_statistics'));
    }

    final home = environment['HOME']?.trim();

    if (home != null && home.isNotEmpty) {
      return Directory(join(home, '.local', 'share', 'purchase_statistics'));
    }

    return Directory(join(Directory.current.path, '.purchase_statistics'));
  }

  static Future<void> _migrateLegacyDesktopDatabase(String databasePath) async {
    final databaseFile = File(databasePath);

    // Wenn die neue Datei existiert, wurde die Migration bereits erledigt.
    if (await databaseFile.exists()) {
      return;
    }

    final legacyDatabasePath = join(await getDatabasesPath(), 'steam_stats.db');

    if (legacyDatabasePath == databasePath) {
      return;
    }

    final legacyDatabaseFile = File(legacyDatabasePath);

    if (!await legacyDatabaseFile.exists()) {
      return;
    }

    // SQLite kann neben der Hauptdatei WAL/SHM-Dateien haben. Sie werden
    // mitkopiert, damit keine offenen Transaktionsdaten verloren gehen.
    await _copyFileIfExists(legacyDatabasePath, databasePath);
    await _copyFileIfExists('$legacyDatabasePath-wal', '$databasePath-wal');
    await _copyFileIfExists('$legacyDatabasePath-shm', '$databasePath-shm');
  }

  static Future<void> _copyFileIfExists(
    String sourcePath,
    String targetPath,
  ) async {
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      return;
    }

    await sourceFile.copy(targetPath);
  }

  static Future<void> _configureDatabase(Database db) async {
    // Foreign Keys sind in SQLite nicht automatisch aktiv. Ohne dieses PRAGMA
    // wuerden Cascades zwischen Collections und Items nicht greifen.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _createDatabase(Database db, int version) async {
    // Grundtabelle fuer alle Kaeufe. Optionale Spalten bleiben nullable, damit
    // ein Kauf auch ohne Steam-Link, Spielzeit oder Notiz gespeichert werden
    // kann.
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
        main_story_hours REAL,
        main_extra_hours REAL,
        completionist_hours REAL,
        backlog_priority_snoozed_until TEXT,
        note TEXT
      )
    ''');

    await _createSettingsTable(db);
    await _createSteamStoreSearchCacheTable(db);
    await _createCollectionsTables(db);
    await _createSteamGoalsTable(db);
    await _createSteamPurchaseMetadataIndexes(db);
    await _createSteamGameMetadataTables(db);
    await _createSteamGameLengthEstimateTable(db);
  }

  /// Fuehrt inkrementelle Migrationen aus.
  ///
  /// Jede `if (oldVersion < X)`-Bedingung beschreibt den Schritt von Version
  /// X-1 nach X. Dadurch kann eine sehr alte Datenbank direkt auf die aktuelle
  /// Version gebracht werden, ohne Zwischenversionen der App zu starten.
  static Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE steam_purchases ADD COLUMN playtime_hours REAL',
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE steam_purchases ADD COLUMN purchase_type TEXT NOT NULL DEFAULT 'game'",
      );
      await db.execute('ALTER TABLE steam_purchases ADD COLUMN edition TEXT');
      await db.execute('ALTER TABLE steam_purchases ADD COLUMN dlc_name TEXT');
    }

    if (oldVersion < 4) {
      await _createSettingsTable(db);
    }

    if (oldVersion >= 4 && oldVersion < 5) {
      await db.execute(
        "ALTER TABLE app_settings ADD COLUMN currency TEXT NOT NULL DEFAULT 'eur'",
      );
    }

    if (oldVersion < 6) {
      await _createSteamStoreSearchCacheTable(db);
    }

    if (oldVersion < 7) {
      await _createCollectionsTables(db);
    }

    if (oldVersion < 8) {
      await _createCollectionItemUniqueIndex(db);
    }

    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE steam_purchases ADD COLUMN steam_app_id INTEGER',
      );
      await _createSteamPurchaseMetadataIndexes(db);
      await _createSteamGameMetadataTables(db);
    }

    if (oldVersion >= 7 && oldVersion < 10) {
      await _addAutomaticCollectionColumns(db);
    }

    if (oldVersion < 10) {
      await _createSteamMetadataRuleLookupIndex(db);
    }

    if (oldVersion >= 9 && oldVersion < 11) {
      await _addSteamGameMetadataReleaseDateColumns(db);
    }

    if (oldVersion < 11) {
      await _createSteamMetadataReleaseDateIndex(db);
    }

    if (oldVersion >= 7 && oldVersion < 12) {
      await _addCollectionIncludeDlcsColumn(db);
    }

    if (oldVersion < 13) {
      await db.execute(
        'ALTER TABLE steam_purchases ADD COLUMN game_status TEXT',
      );
    }

    if (oldVersion < 14) {
      await db.execute(
        'ALTER TABLE steam_purchases ADD COLUMN main_story_hours REAL',
      );
      await db.execute(
        'ALTER TABLE steam_purchases ADD COLUMN main_extra_hours REAL',
      );
      await db.execute(
        'ALTER TABLE steam_purchases ADD COLUMN completionist_hours REAL',
      );
    }

    if (oldVersion < 15) {
      await _createSteamGoalsTable(db);
    }

    if (oldVersion >= 4 && oldVersion < 16) {
      await _addSteamSyncSettingsColumns(db);
    }

    if (oldVersion < 17) {
      await _createSteamGameMetadataUnavailableTable(db);
    }

    if (oldVersion < 18) {
      await _createSteamGameLengthEstimateTable(db);
      await _seedSteamGameLengthEstimatesFromPurchases(db);
    }

    if (oldVersion < 19) {
      await db.execute(
        'ALTER TABLE steam_purchases ADD COLUMN backlog_priority_snoozed_until TEXT',
      );
    }

    if (oldVersion < 20) {
      await db.execute(
        "ALTER TABLE steam_purchases ADD COLUMN launcher TEXT NOT NULL DEFAULT 'steam'",
      );
    }
  }

  static Future<void> _createSettingsTable(Database db) async {
    // Die Settings-Tabelle hat absichtlich genau eine Zeile mit id=1.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
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

  static Future<void> _addSteamSyncSettingsColumns(Database db) async {
    await db.execute(
      'ALTER TABLE app_settings ADD COLUMN steam_account_identifier TEXT',
    );
    await db.execute(
      'ALTER TABLE app_settings ADD COLUMN steam_web_api_key TEXT',
    );
    await db.execute('''
      ALTER TABLE app_settings
      ADD COLUMN steam_include_played_free_games INTEGER NOT NULL DEFAULT 1
    ''');
  }

  static Future<void> _createSteamStoreSearchCacheTable(Database db) async {
    // Cache fuer Steam-Store-Suchen, damit Autocomplete nicht bei jeder
    // Tastatureingabe die API erneut treffen muss.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_store_search_cache (
        query_key TEXT PRIMARY KEY,
        suggestions_json TEXT NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createSteamGoalsTable(Database db) async {
    // Auch Ziele werden als einzelne Settings-Zeile gespeichert.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_goals (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        annual_spending_limit REAL,
        backlog_limit INTEGER,
        unplayed_backlog_limit INTEGER,
        unplayed_backlog_value_limit REAL,
        completion_rate_target REAL
      )
    ''');
  }

  static Future<void> _createCollectionsTables(Database db) async {
    // `collections` beschreibt manuelle oder automatische Sammlungen; konkrete
    // Zuordnungen stehen nur fuer manuelle Sammlungen in `collection_items`.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS collections (
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
      CREATE TABLE IF NOT EXISTS collection_items (
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
      CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id
      ON collection_items(collection_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_collection_items_purchase_id
      ON collection_items(purchase_id)
    ''');

    await _createCollectionItemUniqueIndex(db);
  }

  static Future<void> _addAutomaticCollectionColumns(Database db) async {
    await db.execute(
      "ALTER TABLE collections ADD COLUMN collection_type TEXT NOT NULL DEFAULT 'manual'",
    );
    await db.execute('ALTER TABLE collections ADD COLUMN rule_field TEXT');
    await db.execute('ALTER TABLE collections ADD COLUMN rule_value TEXT');
  }

  static Future<void> _addCollectionIncludeDlcsColumn(Database db) async {
    await db.execute(
      'ALTER TABLE collections ADD COLUMN include_dlcs INTEGER NOT NULL DEFAULT 0',
    );
  }

  static Future<void> _createCollectionItemUniqueIndex(Database db) async {
    // Vor dem Unique Index werden alte Duplikate bereinigt, damit die Migration
    // auch auf bestehenden Datenbanken erfolgreich ist.
    await db.execute('''
      DELETE FROM collection_items
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM collection_items
        GROUP BY collection_id, purchase_id
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_collection_items_unique_purchase
      ON collection_items(collection_id, purchase_id)
    ''');
  }

  static Future<void> _createSteamGameMetadataTables(Database db) async {
    // Metadaten sind in Kopf- und Wertetabelle getrennt: ein Spiel hat genau
    // einen Kopfdatensatz, aber beliebig viele Genre/Tag/Developer/Publisher-
    // Werte.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_game_metadata (
        steam_app_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        release_date TEXT,
        release_date_text TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_game_metadata_values (
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
      CREATE UNIQUE INDEX IF NOT EXISTS idx_steam_metadata_values_unique
      ON steam_game_metadata_values(steam_app_id, field, value)
    ''');

    await _createSteamMetadataRuleLookupIndex(db);
    await _createSteamMetadataReleaseDateIndex(db);
    await _createSteamGameMetadataUnavailableTable(db);
  }

  static Future<void> _createSteamGameMetadataUnavailableTable(
    Database db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_game_metadata_unavailable (
        steam_app_id INTEGER PRIMARY KEY,
        last_checked_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createSteamGameLengthEstimateTable(Database db) async {
    // Hintergrundtabelle fuer teilbare Spiel-Laengen. Sie ist bewusst nicht mit
    // `steam_purchases` verknuepft, damit importierte Schaetzungen keine
    // sichtbaren Kaeufe erzeugen.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_game_length_estimates (
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
      CREATE UNIQUE INDEX IF NOT EXISTS idx_length_estimates_normalized_name
      ON steam_game_length_estimates(normalized_game_name)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_length_estimates_steam_app_id
      ON steam_game_length_estimates(steam_app_id)
      WHERE steam_app_id IS NOT NULL
    ''');
  }

  static Future<void> _seedSteamGameLengthEstimatesFromPurchases(
    Database db,
  ) async {
    final purchaseRows = await db.query(
      'steam_purchases',
      columns: [
        'game_name',
        'steam_app_id',
        'main_story_hours',
        'main_extra_hours',
        'completionist_hours',
      ],
      where:
          "purchase_type = 'game' AND "
          '(main_story_hours IS NOT NULL OR '
          'main_extra_hours IS NOT NULL OR '
          'completionist_hours IS NOT NULL)',
    );

    if (purchaseRows.isEmpty) {
      return;
    }

    final batch = db.batch();
    final seenNames = <String>{};
    final now = DateTime.now().toIso8601String();

    for (final row in purchaseRows) {
      final gameName = row['game_name']?.toString().trim();

      if (gameName == null || gameName.isEmpty) {
        continue;
      }

      final normalizedGameName = normalizeSteamStoreSearchText(gameName);

      if (!seenNames.add(normalizedGameName)) {
        continue;
      }

      batch.insert('steam_game_length_estimates', {
        'game_name': gameName,
        'normalized_game_name': normalizedGameName,
        'steam_app_id': row['steam_app_id'],
        'main_story_hours': row['main_story_hours'],
        'main_extra_hours': row['main_extra_hours'],
        'completionist_hours': row['completionist_hours'],
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  static Future<void> _createSteamMetadataRuleLookupIndex(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_steam_metadata_values_rule_lookup
      ON steam_game_metadata_values(field, value, steam_app_id)
    ''');
  }

  static Future<void> _addSteamGameMetadataReleaseDateColumns(
    Database db,
  ) async {
    await db.execute(
      'ALTER TABLE steam_game_metadata ADD COLUMN release_date TEXT',
    );
    await db.execute(
      'ALTER TABLE steam_game_metadata ADD COLUMN release_date_text TEXT',
    );
  }

  static Future<void> _createSteamMetadataReleaseDateIndex(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_steam_game_metadata_release_date
      ON steam_game_metadata(release_date)
    ''');
  }

  static Future<void> _createSteamPurchaseMetadataIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_steam_purchases_steam_app_id
      ON steam_purchases(steam_app_id)
    ''');
  }
}
