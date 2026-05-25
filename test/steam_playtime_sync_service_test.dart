import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_playtime_sync_service.dart';
import 'package:purchase_statistics/data/steam_purchase_repository.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';

void main() {
  group('SteamOwnedGamesResponseParser', () {
    test('parses owned games and playtime minutes', () {
      final games = SteamOwnedGamesResponseParser.parse('''
        {
          "response": {
            "game_count": 2,
            "games": [
              {"appid": 620, "name": "Portal 2", "playtime_forever": 123},
              {"appid": 400, "name": "Portal", "playtime_forever": 0}
            ]
          }
        }
      ''');

      expect(games, hasLength(2));
      expect(games.first.appId, 400);
      expect(games.first.name, 'Portal');
      expect(games.first.playtimeMinutes, 0);
      expect(games.last.appId, 620);
      expect(games.last.playtimeHours, 2.05);
    });

    test('ignores invalid games and deduplicates by highest playtime', () {
      final games = SteamOwnedGamesResponseParser.parse('''
        {
          "response": {
            "games": [
              {"appid": 620, "name": "Portal 2", "playtime_forever": 60},
              {"appid": 620, "name": "Portal 2", "playtime_forever": 90},
              {"appid": "bad", "name": "Invalid", "playtime_forever": 1},
              {"appid": 10, "name": "Invalid", "playtime_forever": -5}
            ]
          }
        }
      ''');

      expect(games, hasLength(1));
      expect(games.single.appId, 620);
      expect(games.single.playtimeMinutes, 90);
    });
  });

  group('SteamVanityUrlResponseParser', () {
    test('parses resolved steam id', () {
      final steamId = SteamVanityUrlResponseParser.parseSteamId('''
        {
          "response": {
            "steamid": "76561198000000000",
            "success": 1
          }
        }
      ''');

      expect(steamId, '76561198000000000');
    });

    test('returns null when vanity resolution fails', () {
      final steamId = SteamVanityUrlResponseParser.parseSteamId('''
        {
          "response": {
            "success": 42,
            "message": "No match"
          }
        }
      ''');

      expect(steamId, isNull);
    });
  });

  group('SteamPlaytimeSyncService', () {
    test('resolves vanity profile and updates linked purchases only', () async {
      final client = _FakeSteamPlaytimeClient(
        resolvedSteamId: '76561198000000000',
        games: const [
          SteamOwnedGame(appId: 620, name: 'Portal 2', playtimeMinutes: 120),
          SteamOwnedGame(appId: 400, name: 'Portal', playtimeMinutes: 30),
        ],
      );
      final repository = _FakeSteamPurchaseRepository([
        SteamPurchase(
          id: 1,
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          steamAppId: 620,
          price: 9.99,
        ),
        SteamPurchase(
          id: 2,
          purchaseDate: DateTime(2026, 5, 2),
          gameName: 'Stardew Valley',
          steamAppId: 413150,
          price: 4.99,
        ),
        SteamPurchase(
          id: 3,
          purchaseDate: DateTime(2026, 5, 3),
          gameName: 'Unlinked',
          price: 1.99,
        ),
      ]);
      final service = SteamPlaytimeSyncService(
        client: client,
        repository: repository,
      );

      final result = await service.syncPlaytime(
        steamAccountIdentifier: 'https://steamcommunity.com/id/example/',
        apiKey: 'test-key',
        includePlayedFreeGames: true,
      );

      expect(client.vanityUrls, ['example']);
      expect(client.fetchSteamIds, ['76561198000000000']);
      expect(repository.updatedPlaytimeHoursByAppId, {620: 2.0});
      expect(result.ownedGameCount, 2);
      expect(result.linkedPurchaseCount, 2);
      expect(result.matchedPurchaseCount, 1);
      expect(result.updatedPurchaseCount, 1);
    });

    test('uses SteamID64 directly without vanity lookup', () async {
      final client = _FakeSteamPlaytimeClient(games: const []);
      final service = SteamPlaytimeSyncService(
        client: client,
        repository: _FakeSteamPurchaseRepository(const []),
      );

      await service.syncPlaytime(
        steamAccountIdentifier: '76561198000000000',
        apiKey: 'test-key',
        includePlayedFreeGames: false,
      );

      expect(client.vanityUrls, isEmpty);
      expect(client.fetchSteamIds, ['76561198000000000']);
      expect(client.includePlayedFreeGamesValues, [false]);
    });
  });
}

class _FakeSteamPlaytimeClient implements SteamPlaytimeClient {
  final String? resolvedSteamId;
  final List<SteamOwnedGame> games;
  final List<String> vanityUrls = [];
  final List<String> fetchSteamIds = [];
  final List<bool> includePlayedFreeGamesValues = [];

  _FakeSteamPlaytimeClient({this.resolvedSteamId, required this.games});

  @override
  Future<List<SteamOwnedGame>> fetchOwnedGames({
    required String apiKey,
    required String steamId,
    required bool includePlayedFreeGames,
  }) async {
    fetchSteamIds.add(steamId);
    includePlayedFreeGamesValues.add(includePlayedFreeGames);

    return games;
  }

  @override
  Future<String?> resolveSteamIdFromVanityUrl({
    required String apiKey,
    required String vanityUrl,
  }) async {
    vanityUrls.add(vanityUrl);

    return resolvedSteamId;
  }
}

class _FakeSteamPurchaseRepository extends SteamPurchaseRepository {
  final List<SteamPurchase> purchases;
  Map<int, double> updatedPlaytimeHoursByAppId = const {};

  _FakeSteamPurchaseRepository(this.purchases);

  @override
  Future<List<SteamPurchase>> getAllPurchases() async {
    return purchases;
  }

  @override
  Future<int> updatePlaytimeHoursBySteamAppId(
    Map<int, double> playtimeHoursBySteamAppId,
  ) async {
    updatedPlaytimeHoursByAppId = Map.of(playtimeHoursBySteamAppId);

    return playtimeHoursBySteamAppId.length;
  }
}
