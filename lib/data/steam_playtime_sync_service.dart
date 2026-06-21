// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'http_response_reader.dart';
import 'resource_lifecycle.dart';
import 'steam_purchase_repository.dart';

/// Spielzeile aus der Steam-Owned-Games-API.
class SteamOwnedGame {
  final int appId;
  final String? name;
  final int playtimeMinutes;

  const SteamOwnedGame({
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
  });

  double get playtimeHours => playtimeMinutes / 60;
}

/// Ergebnis eines Spielzeit-Syncs, damit die UI eine konkrete Zusammenfassung
/// anzeigen kann.
class SteamPlaytimeSyncResult {
  final int ownedGameCount;
  final int linkedPurchaseCount;
  final int matchedPurchaseCount;
  final int updatedPurchaseCount;

  const SteamPlaytimeSyncResult({
    required this.ownedGameCount,
    required this.linkedPurchaseCount,
    required this.matchedPurchaseCount,
    required this.updatedPurchaseCount,
  });
}

/// Fachlicher Fehler fuer den Steam-Sync.
///
/// Netzwerk-, Timeout- und Parsing-Details werden in nutzerverstaendliche
/// Meldungen uebersetzt.
class SteamPlaytimeSyncException implements Exception {
  final String message;

  const SteamPlaytimeSyncException(this.message);

  @override
  String toString() {
    return message;
  }
}

/// Normalisiert technische Steam-API-Fehler in `SteamPlaytimeSyncException`.
Future<T> _runSteamApiOperation<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on SteamPlaytimeSyncException {
    rethrow;
  } on TimeoutException {
    throw const SteamPlaytimeSyncException('Steam API request timed out.');
  } on SocketException {
    throw const SteamPlaytimeSyncException(
      'Steam API request failed. Check your network connection.',
    );
  } on HttpBodyTooLargeException {
    throw const SteamPlaytimeSyncException(
      'Steam API response was larger than expected.',
    );
  } on FormatException {
    throw const SteamPlaytimeSyncException(
      'Steam API response could not be read.',
    );
  } on HttpException {
    throw const SteamPlaytimeSyncException('Steam API request failed.');
  } catch (_) {
    throw const SteamPlaytimeSyncException('Steam API request failed.');
  }
}

/// Schnittstelle fuer die beiden Steam-Web-API-Aufrufe, die der Sync braucht.
abstract class SteamPlaytimeClient {
  Future<List<SteamOwnedGame>> fetchOwnedGames({
    required String apiKey,
    required String steamId,
    required bool includePlayedFreeGames,
  });

  Future<String?> resolveSteamIdFromVanityUrl({
    required String apiKey,
    required String vanityUrl,
  });
}

/// HTTP-Implementierung fuer Steam-Web-API-Spielzeiten.
class HttpSteamPlaytimeClient
    implements SteamPlaytimeClient, DisposableResource {
  static const int _maxResponseBytes = 10 * 1024 * 1024;

  final HttpClient _httpClient;
  final Duration timeout;
  final bool _ownsHttpClient;

  HttpSteamPlaytimeClient({
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 5),
  }) : _httpClient = httpClient ?? HttpClient(),
       _ownsHttpClient = httpClient == null {
    _httpClient.connectionTimeout = timeout;
  }

  @override
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  @override
  Future<List<SteamOwnedGame>> fetchOwnedGames({
    required String apiKey,
    required String steamId,
    required bool includePlayedFreeGames,
  }) async {
    return _runSteamApiOperation(() async {
      final uri = Uri.https(
        'api.steampowered.com',
        '/IPlayerService/GetOwnedGames/v1/',
        {
          'key': apiKey,
          'steamid': steamId,
          'include_appinfo': 'true',
          'include_played_free_games': includePlayedFreeGames.toString(),
          'format': 'json',
        },
      );
      final body = await _getJsonBody(uri);

      return SteamOwnedGamesResponseParser.parse(body);
    });
  }

  @override
  Future<String?> resolveSteamIdFromVanityUrl({
    required String apiKey,
    required String vanityUrl,
  }) async {
    return _runSteamApiOperation(() async {
      final uri = Uri.https(
        'api.steampowered.com',
        '/ISteamUser/ResolveVanityURL/v1/',
        {
          'key': apiKey,
          'vanityurl': vanityUrl,
          'url_type': '1',
          'format': 'json',
        },
      );
      final body = await _getJsonBody(uri);

      return SteamVanityUrlResponseParser.parseSteamId(body);
    });
  }

  Future<String> _getJsonBody(Uri uri) async {
    final request = await _httpClient.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(timeout);

    if (response.statusCode != HttpStatus.ok) {
      // Nicht-200 wird als fachlicher Sync-Fehler gemeldet, damit die UI keinen
      // rohen HttpException-Text anzeigen muss.
      throw SteamPlaytimeSyncException(
        'Steam API returned HTTP ${response.statusCode}.',
      );
    }

    return readUtf8HttpBody(
      response,
      maxBytes: _maxResponseBytes,
      timeout: timeout,
    );
  }
}

/// Synchronisiert Steam-Spielzeiten in lokale Kaeufe.
///
/// Der Service loest Vanity-URLs auf, liest die Steam-Bibliothek, matched ueber
/// gespeicherte App-IDs und schreibt nur geaenderte Spielzeiten zurueck.
class SteamPlaytimeSyncService implements DisposableResource {
  final SteamPlaytimeClient client;
  final SteamPurchaseRepository repository;
  final bool _ownsClient;

  SteamPlaytimeSyncService({
    SteamPlaytimeClient? client,
    SteamPurchaseRepository? repository,
  }) : client = client ?? HttpSteamPlaytimeClient(),
       repository = repository ?? SteamPurchaseRepository(),
       _ownsClient = client == null;

  @override
  void dispose() {
    if (_ownsClient) {
      disposeResource(client);
    }
  }

  Future<SteamPlaytimeSyncResult> syncPlaytime({
    required String steamAccountIdentifier,
    required String apiKey,
    required bool includePlayedFreeGames,
  }) async {
    final normalizedAccountIdentifier = _normalizeAccountIdentifier(
      steamAccountIdentifier,
    );
    final normalizedApiKey = apiKey.trim();

    if (normalizedAccountIdentifier.isEmpty || normalizedApiKey.isEmpty) {
      throw const SteamPlaytimeSyncException(
        'Steam account and Web API key are required.',
      );
    }

    final steamId = await _runSteamApiOperation(
      () => _resolveSteamId(
        apiKey: normalizedApiKey,
        accountIdentifier: normalizedAccountIdentifier,
      ),
    );
    final ownedGames = await _runSteamApiOperation(
      () => client.fetchOwnedGames(
        apiKey: normalizedApiKey,
        steamId: steamId,
        includePlayedFreeGames: includePlayedFreeGames,
      ),
    );
    final purchases = await repository.getAllPurchases();
    // Nur Kaeufe mit Steam-App-ID koennen gegen die Steam-Bibliothek gematcht
    // werden.
    final linkedPurchases = purchases
        .where((purchase) {
          return purchase.steamAppId != null;
        })
        .toList(growable: false);
    final playtimeHoursByAppId = {
      for (final game in ownedGames) game.appId: game.playtimeHours,
    };
    final matchedPurchases = linkedPurchases
        .where((purchase) {
          return playtimeHoursByAppId.containsKey(purchase.steamAppId);
        })
        .toList(growable: false);
    final matchedAppIds = matchedPurchases
        .map((purchase) => purchase.steamAppId)
        .whereType<int>()
        .toSet();
    final updatedPurchaseCount = await repository
        .updatePlaytimeHoursBySteamAppId({
          for (final appId in matchedAppIds)
            appId: playtimeHoursByAppId[appId]!,
        });

    return SteamPlaytimeSyncResult(
      ownedGameCount: ownedGames.length,
      linkedPurchaseCount: linkedPurchases.length,
      matchedPurchaseCount: matchedPurchases.length,
      updatedPurchaseCount: updatedPurchaseCount,
    );
  }

  Future<String> _resolveSteamId({
    required String apiKey,
    required String accountIdentifier,
  }) async {
    // SteamID64 kann direkt verwendet werden; Vanity-Namen muessen ueber die API
    // aufgeloest werden.
    if (_isSteamId64(accountIdentifier)) {
      return accountIdentifier;
    }

    final steamId = await client.resolveSteamIdFromVanityUrl(
      apiKey: apiKey,
      vanityUrl: accountIdentifier,
    );

    if (steamId == null || steamId.trim().isEmpty) {
      throw const SteamPlaytimeSyncException(
        'Steam profile could not be resolved.',
      );
    }

    return steamId;
  }

  String _normalizeAccountIdentifier(String value) {
    final trimmedValue = value.trim();
    final steamCommunityMatch = RegExp(
      r'(?:https?://)?(?:www\.)?steamcommunity\.com/(?:id|profiles)/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(trimmedValue);

    if (steamCommunityMatch != null) {
      // Aus kompletten Profil-URLs wird nur der relevante id/profiles-Teil
      // extrahiert.
      return Uri.decodeComponent(steamCommunityMatch.group(1)!).trim();
    }

    return trimmedValue.replaceFirst(RegExp(r'/+$'), '');
  }

  bool _isSteamId64(String value) {
    return RegExp(r'^\d{16,20}$').hasMatch(value);
  }
}

/// Parser fuer `IPlayerService/GetOwnedGames`.
class SteamOwnedGamesResponseParser {
  const SteamOwnedGamesResponseParser._();

  static List<SteamOwnedGame> parse(String responseBody) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, Object?>) {
      return const [];
    }

    final response = decoded['response'];

    if (response is! Map<String, Object?>) {
      return const [];
    }

    final games = response['games'];

    if (games is! List<Object?>) {
      return const [];
    }

    final gamesByAppId = <int, SteamOwnedGame>{};

    // Falls Steam eine App mehrfach liefert, behalten wir die Variante mit der
    // hoechsten Spielzeit.
    for (final game in games) {
      if (game is! Map<String, Object?>) {
        continue;
      }

      final appId = _parseInt(game['appid']);
      final playtimeMinutes = _parseInt(game['playtime_forever']);

      if (appId == null || playtimeMinutes == null || playtimeMinutes < 0) {
        continue;
      }

      final name = game['name']?.toString().trim();
      final ownedGame = SteamOwnedGame(
        appId: appId,
        name: name == null || name.isEmpty ? null : name,
        playtimeMinutes: playtimeMinutes,
      );
      final currentGame = gamesByAppId[appId];

      if (currentGame == null ||
          ownedGame.playtimeMinutes > currentGame.playtimeMinutes) {
        gamesByAppId[appId] = ownedGame;
      }
    }

    final result = gamesByAppId.values.toList(growable: false)
      ..sort((a, b) => a.appId.compareTo(b.appId));

    return result;
  }

  static int? _parseInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}

/// Parser fuer `ISteamUser/ResolveVanityURL`.
class SteamVanityUrlResponseParser {
  const SteamVanityUrlResponseParser._();

  static String? parseSteamId(String responseBody) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, Object?>) {
      return null;
    }

    final response = decoded['response'];

    if (response is! Map<String, Object?>) {
      return null;
    }

    final success = response['success'];

    if (success != 1 && success != '1') {
      return null;
    }

    final steamId = response['steamid']?.toString().trim();

    if (steamId == null || steamId.isEmpty) {
      return null;
    }

    return steamId;
  }
}
