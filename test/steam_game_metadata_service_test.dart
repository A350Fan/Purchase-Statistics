import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_game_metadata_client.dart';
import 'package:purchase_statistics/data/steam_game_metadata_repository.dart';
import 'package:purchase_statistics/data/steam_game_metadata_service.dart';
import 'package:purchase_statistics/models/steam_game_metadata.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
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
      now: () => DateTime.utc(2026, 5, 24, 12),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('refreshes and stores metadata for a linked purchase', () async {
    final service = SteamGameMetadataService(
      client: _FakeSteamGameMetadataClient(
        const SteamGameMetadata(
          steamAppId: 620,
          name: 'Portal 2',
          genres: ['Action'],
        ),
      ),
      repository: repository,
    );
    final purchase = SteamPurchase(
      id: 1,
      purchaseDate: DateTime(2026, 5, 24),
      gameName: 'Portal 2',
      steamAppId: 620,
      price: 9.99,
    );

    final metadata = await service.refreshMetadataForPurchase(
      purchase: purchase,
      language: 'german',
      countryCode: 'DE',
    );
    final storedMetadata = await repository.getMetadata(620);

    expect(metadata, isNotNull);
    expect(storedMetadata, isNotNull);
    expect(storedMetadata!.name, 'Portal 2');
    expect(storedMetadata.genres, ['Action']);
  });

  test('does not call client for purchases without Steam app id', () async {
    final client = _FakeSteamGameMetadataClient(null);
    final service = SteamGameMetadataService(
      client: client,
      repository: repository,
    );
    final purchase = SteamPurchase(
      id: 1,
      purchaseDate: DateTime(2026, 5, 24),
      gameName: 'Manual game',
      price: 9.99,
    );

    final metadata = await service.refreshMetadataForPurchase(
      purchase: purchase,
      language: 'german',
      countryCode: 'DE',
    );

    expect(metadata, isNull);
    expect(client.callCount, 0);
  });
}

class _FakeSteamGameMetadataClient implements SteamGameMetadataClient {
  final SteamGameMetadata? metadata;
  int callCount = 0;

  _FakeSteamGameMetadataClient(this.metadata);

  @override
  Future<SteamGameMetadata?> fetchMetadata({
    required int steamAppId,
    required String language,
    required String countryCode,
  }) async {
    callCount++;
    return metadata;
  }
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
}
