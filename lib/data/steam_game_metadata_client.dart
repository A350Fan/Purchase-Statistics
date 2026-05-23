import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/steam_game_metadata.dart';

abstract class SteamGameMetadataClient {
  Future<SteamGameMetadata?> fetchMetadata({
    required int steamAppId,
    required String language,
    required String countryCode,
  });
}

class HttpSteamGameMetadataClient implements SteamGameMetadataClient {
  final HttpClient _httpClient;
  final Duration timeout;

  HttpSteamGameMetadataClient({
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 3),
  }) : _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = timeout;
  }

  @override
  Future<SteamGameMetadata?> fetchMetadata({
    required int steamAppId,
    required String language,
    required String countryCode,
  }) async {
    final uri = Uri.https('store.steampowered.com', '/api/appdetails', {
      'appids': steamAppId.toString(),
      'cc': countryCode,
      'l': language,
    });
    final request = await _httpClient.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(timeout);

    if (response.statusCode != HttpStatus.ok) {
      return null;
    }

    final body = await response.transform(utf8.decoder).join().timeout(timeout);

    return SteamGameMetadataResponseParser.parse(
      body,
      requestedSteamAppId: steamAppId,
    );
  }
}

class SteamGameMetadataResponseParser {
  const SteamGameMetadataResponseParser._();

  static SteamGameMetadata? parse(
    String responseBody, {
    required int requestedSteamAppId,
  }) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, Object?>) {
      return null;
    }

    final appEntry = decoded[requestedSteamAppId.toString()];

    if (appEntry is! Map<String, Object?> || appEntry['success'] != true) {
      return null;
    }

    final data = appEntry['data'];

    if (data is! Map<String, Object?>) {
      return null;
    }

    final name = data['name']?.toString().trim();

    if (name == null || name.isEmpty) {
      return null;
    }

    return SteamGameMetadata(
      steamAppId: _parseSteamAppId(data['steam_appid']) ?? requestedSteamAppId,
      name: name,
      genres: _parseDescriptionList(data['genres']),
      tags: [
        ..._parseDescriptionList(data['categories']),
        ..._parseTags(data['tags']),
      ],
      developers: _parseStringList(data['developers']),
      publishers: _parseStringList(data['publishers']),
    );
  }

  static int? _parseSteamAppId(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static List<String> _parseDescriptionList(Object? value) {
    if (value is! List<Object?>) {
      return const [];
    }

    return _uniqueValues(
      value.whereType<Map<String, Object?>>().map(
        (entry) => entry['description']?.toString(),
      ),
    );
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List<Object?>) {
      return const [];
    }

    return _uniqueValues(value.map((entry) => entry?.toString()));
  }

  static List<String> _parseTags(Object? value) {
    if (value is Map<String, Object?>) {
      return _uniqueValues(value.keys);
    }

    if (value is List<Object?>) {
      return _uniqueValues(
        value.map((entry) {
          if (entry is Map<String, Object?>) {
            return entry['name']?.toString() ??
                entry['description']?.toString();
          }

          return entry?.toString();
        }),
      );
    }

    return const [];
  }

  static List<String> _uniqueValues(Iterable<String?> values) {
    final valuesByKey = <String, String>{};

    for (final value in values) {
      final trimmedValue = value?.trim();

      if (trimmedValue == null || trimmedValue.isEmpty) {
        continue;
      }

      valuesByKey.putIfAbsent(_normalize(trimmedValue), () => trimmedValue);
    }

    return valuesByKey.values.toList(growable: false);
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
