import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static Database? _database;
  static bool _isDesktopFactoryConfigured = false;

  static Future<Database> get instance async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  static Future<Database> _openDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _configureDesktopFactory();
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'steam_stats.db');

    return openDatabase(
      path,
      version: 10,
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

  static Future<void> _configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE steam_purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_date TEXT NOT NULL,
        purchase_type TEXT NOT NULL DEFAULT 'game',
        game_name TEXT NOT NULL,
        edition TEXT,
        dlc_name TEXT,
        steam_app_id INTEGER,
        price REAL NOT NULL,
        original_price REAL,
        playtime_hours REAL,
        note TEXT
      )
    ''');

    await _createSettingsTable(db);
    await _createSteamStoreSearchCacheTable(db);
    await _createCollectionsTables(db);
    await _createSteamPurchaseMetadataIndexes(db);
    await _createSteamGameMetadataTables(db);
  }

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
  }

  static Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        theme_mode TEXT NOT NULL,
        language TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'eur'
      )
    ''');
  }

  static Future<void> _createSteamStoreSearchCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_store_search_cache (
        query_key TEXT PRIMARY KEY,
        suggestions_json TEXT NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createCollectionsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        sort_mode TEXT NOT NULL DEFAULT 'manual',
        collection_type TEXT NOT NULL DEFAULT 'manual',
        rule_field TEXT,
        rule_value TEXT,
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

  static Future<void> _createCollectionItemUniqueIndex(Database db) async {
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS steam_game_metadata (
        steam_app_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
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
  }

  static Future<void> _createSteamMetadataRuleLookupIndex(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_steam_metadata_values_rule_lookup
      ON steam_game_metadata_values(field, value, steam_app_id)
    ''');
  }

  static Future<void> _createSteamPurchaseMetadataIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_steam_purchases_steam_app_id
      ON steam_purchases(steam_app_id)
    ''');
  }
}
