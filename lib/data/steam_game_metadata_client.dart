import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/steam_game_metadata.dart';
import 'http_response_reader.dart';
import 'resource_lifecycle.dart';

abstract class SteamGameMetadataClient {
  Future<SteamGameMetadata?> fetchMetadata({
    required int steamAppId,
    required String language,
    required String countryCode,
  });
}

class HttpSteamGameMetadataClient
    implements SteamGameMetadataClient, DisposableResource {
  static const int _maxResponseBytes = 5 * 1024 * 1024;

  final HttpClient _httpClient;
  final Duration timeout;
  final bool _ownsHttpClient;

  HttpSteamGameMetadataClient({
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 3),
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
      throw HttpException(
        'Steam appdetails returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }

    final body = await readUtf8HttpBody(
      response,
      maxBytes: _maxResponseBytes,
      timeout: timeout,
    );

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

    final releaseDateText = _parseReleaseDateText(data['release_date']);

    return SteamGameMetadata(
      steamAppId: _parseSteamAppId(data['steam_appid']) ?? requestedSteamAppId,
      name: name,
      releaseDate: _parseReleaseDate(releaseDateText),
      releaseDateText: releaseDateText,
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

  static String? _parseReleaseDateText(Object? value) {
    if (value is Map<String, Object?>) {
      final date = value['date']?.toString().trim();

      if (date == null || date.isEmpty) {
        return null;
      }

      return date;
    }

    final date = value?.toString().trim();

    if (date == null || date.isEmpty) {
      return null;
    }

    return date;
  }

  static DateTime? _parseReleaseDate(String? value) {
    if (value == null) {
      return null;
    }

    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    final isoDate = DateTime.tryParse(trimmedValue);

    if (isoDate != null) {
      return DateTime.utc(isoDate.year, isoDate.month, isoDate.day);
    }

    final numericDate = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ).firstMatch(trimmedValue);

    if (numericDate != null) {
      return _dateFromParts(
        year: int.tryParse(numericDate.group(3)!),
        month: int.tryParse(numericDate.group(2)!),
        day: int.tryParse(numericDate.group(1)!),
      );
    }

    final normalizedValue = trimmedValue
        .toLowerCase()
        .replaceAll(',', ' ')
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final tokens = normalizedValue.split(' ');
    final yearIndex = tokens.indexWhere(
      (token) => RegExp(r'^\d{4}$').hasMatch(token),
    );

    if (yearIndex == -1) {
      return null;
    }

    final year = int.tryParse(tokens[yearIndex]);

    if (tokens.length == 1) {
      return _dateFromParts(year: year, month: 1, day: 1);
    }

    if (yearIndex >= 2) {
      final day = int.tryParse(tokens[yearIndex - 2]);
      final month = _parseMonth(tokens[yearIndex - 1]);

      if (day != null && month != null) {
        return _dateFromParts(year: year, month: month, day: day);
      }
    }

    if (yearIndex >= 1) {
      final month = _parseMonth(tokens[yearIndex - 1]);

      if (month != null) {
        return _dateFromParts(year: year, month: month, day: 1);
      }
    }

    if (yearIndex + 2 < tokens.length) {
      final month = _parseMonth(tokens[yearIndex + 1]);
      final day = int.tryParse(tokens[yearIndex + 2]);

      if (month != null && day != null) {
        return _dateFromParts(year: year, month: month, day: day);
      }
    }

    if (yearIndex >= 2) {
      final month = _parseMonth(tokens[yearIndex - 2]);
      final day = int.tryParse(tokens[yearIndex - 1]);

      if (month != null && day != null) {
        return _dateFromParts(year: year, month: month, day: day);
      }
    }

    return _dateFromParts(year: year, month: 1, day: 1);
  }

  static DateTime? _dateFromParts({
    required int? year,
    required int? month,
    required int? day,
  }) {
    if (year == null ||
        month == null ||
        day == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }

    return DateTime.utc(year, month, day);
  }

  static int? _parseMonth(String value) {
    return switch (value) {
      'jan' || 'january' || 'januar' => 1,
      'feb' || 'february' || 'februar' => 2,
      'mar' || 'march' || 'mär' || 'maerz' || 'märz' => 3,
      'apr' || 'april' => 4,
      'may' || 'mai' => 5,
      'jun' || 'june' || 'juni' => 6,
      'jul' || 'july' || 'juli' => 7,
      'aug' || 'august' => 8,
      'sep' || 'sept' || 'september' => 9,
      'oct' || 'october' || 'okt' || 'oktober' => 10,
      'nov' || 'november' => 11,
      'dec' || 'december' || 'dez' || 'dezember' => 12,
      _ => null,
    };
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
