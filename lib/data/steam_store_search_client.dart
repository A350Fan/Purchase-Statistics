import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/steam_purchase.dart';
import '../models/steam_store_search_suggestion.dart';
import 'steam_store_search_text.dart';

abstract class SteamStoreSearchClient {
  Future<List<SteamStoreSearchSuggestion>> search({
    required String query,
    required SteamPurchaseType purchaseType,
    required String language,
    required String countryCode,
  });
}

class HttpSteamStoreSearchClient implements SteamStoreSearchClient {
  static const Duration _minimumRequestInterval = Duration(seconds: 2);

  final HttpClient _httpClient;
  final Duration timeout;

  DateTime? _lastRequestStartedAt;
  Future<void> _requestQueue = Future.value();

  HttpSteamStoreSearchClient({
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 2),
  }) : _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = timeout;
  }

  @override
  Future<List<SteamStoreSearchSuggestion>> search({
    required String query,
    required SteamPurchaseType purchaseType,
    required String language,
    required String countryCode,
  }) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return [];
    }

    await _waitForRequestSlot();

    final uri = Uri.https('store.steampowered.com', '/api/storesearch/', {
      'term': trimmedQuery,
      'cc': countryCode,
      'l': language,
    });

    final request = await _httpClient.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(timeout);

    if (response.statusCode != HttpStatus.ok) {
      return [];
    }

    final body = await response.transform(utf8.decoder).join().timeout(timeout);

    return SteamStoreSearchResponseParser.parse(
      body,
      fallbackItemType: SteamStoreItemType.fromPurchaseType(purchaseType),
    );
  }

  Future<void> _waitForRequestSlot() {
    final slot = _requestQueue.then((_) async {
      final lastRequestStartedAt = _lastRequestStartedAt;

      if (lastRequestStartedAt != null) {
        final elapsed = DateTime.now().difference(lastRequestStartedAt);
        final remainingWait = _minimumRequestInterval - elapsed;

        if (!remainingWait.isNegative) {
          await Future<void>.delayed(remainingWait);
        }
      }

      _lastRequestStartedAt = DateTime.now();
    });

    _requestQueue = slot.catchError((_) {});

    return slot;
  }
}

class SteamStoreSearchResponseParser {
  const SteamStoreSearchResponseParser._();

  static List<SteamStoreSearchSuggestion> parse(
    String responseBody, {
    required SteamStoreItemType fallbackItemType,
  }) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, Object?>) {
      return [];
    }

    final items = decoded['items'];

    if (items is! List<Object?>) {
      return [];
    }

    final suggestionsByName = <String, SteamStoreSearchSuggestion>{};

    for (final item in items) {
      if (item is! Map<String, Object?>) {
        continue;
      }

      final name = item['name']?.toString().trim();
      final appIdValue = item['id'] ?? item['appid'] ?? item['app_id'];

      if (name == null || name.isEmpty || appIdValue is! num) {
        continue;
      }

      suggestionsByName.putIfAbsent(
        _normalizeName(name),
        () => SteamStoreSearchSuggestion(
          appId: appIdValue.toInt(),
          name: name,
          itemType: _parseItemType(item['type']) ?? fallbackItemType,
        ),
      );
    }

    return suggestionsByName.values.toList(growable: false);
  }

  static SteamStoreItemType? _parseItemType(Object? value) {
    final normalizedValue = value?.toString().trim().toLowerCase();

    return switch (normalizedValue) {
      'game' => SteamStoreItemType.game,
      'dlc' => SteamStoreItemType.dlc,
      _ => null,
    };
  }

  static String _normalizeName(String value) {
    return normalizeSteamStoreSearchText(value);
  }
}
