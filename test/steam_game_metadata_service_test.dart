// SPDX-License-Identifier: GPL-3.0-or-later
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

  test('refreshes missing metadata for unique linked purchases', () async {
    await repository.upsertMetadata(
      const SteamGameMetadata(steamAppId: 620, name: 'Portal 2'),
    );
    final client = _MappedSteamGameMetadataClient({
      400: const SteamGameMetadata(steamAppId: 400, name: 'Portal'),
    });
    final service = SteamGameMetadataService(
      client: client,
      repository: repository,
    );

    final result = await service.refreshMetadataForPurchases(
      purchases: [
        SteamPurchase(
          id: 1,
          purchaseDate: DateTime(2026, 5, 24),
          gameName: 'Portal 2',
          steamAppId: 620,
          price: 9.99,
        ),
        SteamPurchase(
          id: 2,
          purchaseDate: DateTime(2026, 5, 24),
          gameName: 'Portal',
          steamAppId: 400,
          price: 1.99,
        ),
        SteamPurchase(
          id: 3,
          purchaseDate: DateTime(2026, 5, 24),
          gameName: 'Portal duplicate',
          steamAppId: 400,
          price: 1.99,
        ),
        SteamPurchase(
          id: 4,
          purchaseDate: DateTime(2026, 5, 24),
          gameName: 'Manual',
          price: 1.99,
        ),
      ],
      language: 'german',
      countryCode: 'DE',
      onlyMissing: true,
    );

    expect(result.attempted, 1);
    expect(result.refreshed, 1);
    expect(result.skipped, 1);
    expect(result.failed, 0);
    expect(client.requestedSteamAppIds, [400]);
    expect((await repository.getMetadata(400))?.name, 'Portal');
  });

  test('skips recently unavailable Steam metadata during refresh', () async {
    final client = _MappedSteamGameMetadataClient({1080110: null});
    final service = SteamGameMetadataService(
      client: client,
      repository: repository,
      unavailableMetadataRetryDelay: const Duration(days: 7),
    );
    final purchases = [
      SteamPurchase(
        id: 1,
        purchaseDate: DateTime(2026, 5, 24),
        gameName: 'F1 2020',
        steamAppId: 1080110,
        price: 9.99,
      ),
    ];

    final firstResult = await service.refreshMetadataForPurchases(
      purchases: purchases,
      language: 'german',
      countryCode: 'DE',
      onlyMissing: true,
    );
    final secondResult = await service.refreshMetadataForPurchases(
      purchases: purchases,
      language: 'german',
      countryCode: 'DE',
      onlyMissing: true,
    );

    expect(firstResult.attempted, 1);
    expect(firstResult.refreshed, 0);
    expect(firstResult.failed, 1);
    expect(secondResult.attempted, 0);
    expect(secondResult.skipped, 1);
    expect(secondResult.failed, 0);
    expect(client.requestedSteamAppIds, [1080110]);
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

class _MappedSteamGameMetadataClient implements SteamGameMetadataClient {
  final Map<int, SteamGameMetadata?> metadataBySteamAppId;
  final List<int> requestedSteamAppIds = [];

  _MappedSteamGameMetadataClient(this.metadataBySteamAppId);

  @override
  Future<SteamGameMetadata?> fetchMetadata({
    required int steamAppId,
    required String language,
    required String countryCode,
  }) async {
    requestedSteamAppIds.add(steamAppId);

    return metadataBySteamAppId[steamAppId];
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

  await db.execute('''
    CREATE TABLE steam_game_metadata_unavailable (
      steam_app_id INTEGER PRIMARY KEY,
      last_checked_at TEXT NOT NULL
    )
  ''');
}
