import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_game_metadata_repository.dart';
import 'package:purchase_statistics/models/steam_game_metadata.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SteamGameMetadataRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createTestSchema(db);
        },
      ),
    );
    repository = SteamGameMetadataRepository(
      databaseProvider: () async => db,
      now: () => DateTime.utc(2026, 5, 23, 12),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('stores and reloads Steam metadata values', () async {
    final metadata = SteamGameMetadata(
      steamAppId: 620,
      name: 'Portal 2',
      releaseDate: DateTime.utc(2011, 4, 18),
      releaseDateText: 'Apr 18, 2011',
      genres: ['Action', 'Adventure'],
      tags: ['Puzzle', 'Co-op'],
      developers: ['Valve'],
      publishers: ['Valve'],
    );

    await repository.upsertMetadata(metadata);

    final storedMetadata = await repository.getMetadata(620);

    expect(storedMetadata, isNotNull);
    expect(storedMetadata!.name, 'Portal 2');
    expect(storedMetadata.releaseDate, DateTime.utc(2011, 4, 18));
    expect(storedMetadata.releaseDateText, 'Apr 18, 2011');
    expect(storedMetadata.genres, ['Action', 'Adventure']);
    expect(storedMetadata.tags, ['Co-op', 'Puzzle']);
    expect(storedMetadata.developers, ['Valve']);
    expect(storedMetadata.publishers, ['Valve']);
  });

  test('replaces existing metadata values on upsert', () async {
    await repository.upsertMetadata(
      const SteamGameMetadata(
        steamAppId: 620,
        name: 'Portal 2',
        genres: ['Action'],
      ),
    );
    await repository.upsertMetadata(
      const SteamGameMetadata(
        steamAppId: 620,
        name: 'Portal 2',
        genres: ['Adventure'],
      ),
    );

    final storedMetadata = await repository.getMetadata(620);

    expect(storedMetadata!.genres, ['Adventure']);
  });
}

Future<void> _createTestSchema(Database db) async {
  await db.execute('''
    CREATE TABLE steam_game_metadata (
      steam_app_id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      release_date TEXT,
      release_date_text TEXT,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE steam_game_metadata_values (
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
    CREATE UNIQUE INDEX idx_steam_metadata_values_unique
    ON steam_game_metadata_values(steam_app_id, field, value)
  ''');
}
