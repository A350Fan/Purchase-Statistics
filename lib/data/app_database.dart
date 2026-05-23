import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static Database? _database;

  static Future<Database> get instance async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  static Future<Database> _openDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'steam_stats.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
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
        price REAL NOT NULL,
        original_price REAL,
        playtime_hours REAL,
        note TEXT
      )
    ''');

    await _createSettingsTable(db);
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
  }

  static Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        theme_mode TEXT NOT NULL,
        language TEXT NOT NULL
      )
    ''');
  }
}
