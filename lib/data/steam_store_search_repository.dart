import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/steam_purchase.dart';
import '../models/steam_store_search_suggestion.dart';
import 'app_database.dart';
import 'resource_lifecycle.dart';
import 'steam_store_search_client.dart';
import 'steam_store_search_text.dart';

/// Gemeinsame Suchschnittstelle fuer echte Steam-Suche und Test-Doubles.
abstract class SteamStoreSearchSource {
  Future<List<SteamStoreSearchSuggestion>> search({
    required String query,
    required SteamPurchaseType purchaseType,
    required String language,
    required String countryCode,
    String? associatedGameName,
  });
}

/// Kombiniert Steam-Store-Suche mit lokalem SQLite-Cache.
///
/// Das Repository entscheidet, ob eine Suchanfrage lang genug ist, baut bei DLCs
/// einen besseren Suchbegriff und faellt bei Netzwerkfehlern auf vorhandene
/// Cache-Daten zurueck.
class SteamStoreSearchRepository
    implements SteamStoreSearchSource, DisposableResource {
  static const int minimumQueryLength = 3;

  final SteamStoreSearchClient client;
  final SteamStoreSearchCache cache;
  final DateTime Function() now;
  final Duration resultCacheDuration;
  final Duration emptyResultCacheDuration;
  final bool _ownsClient;

  SteamStoreSearchRepository({
    SteamStoreSearchClient? client,
    SteamStoreSearchCache? cache,
    DateTime Function()? now,
    this.resultCacheDuration = const Duration(days: 30),
    this.emptyResultCacheDuration = const Duration(days: 1),
  }) : client = client ?? HttpSteamStoreSearchClient(),
       cache = cache ?? SqliteSteamStoreSearchCache(),
       now = now ?? DateTime.now,
       _ownsClient = client == null;

  @override
  void dispose() {
    if (!_ownsClient) {
      return;
    }

    disposeResource(client);
  }

  @override
  Future<List<SteamStoreSearchSuggestion>> search({
    required String query,
    required SteamPurchaseType purchaseType,
    required String language,
    required String countryCode,
    String? associatedGameName,
  }) async {
    // DLC-Suchen funktionieren bei Steam oft besser, wenn der Name des
    // Basisspiels vorangestellt wird.
    final searchTerm = _buildSearchTerm(
      query: query,
      purchaseType: purchaseType,
      associatedGameName: associatedGameName,
    );
    final normalizedSearchTerm = _normalizeSearchTerm(searchTerm);

    if (normalizedSearchTerm.length < minimumQueryLength) {
      return [];
    }

    // Der Cache-Key enthaelt Sprache, Land und Kaufart, weil Steam je nach
    // Region/Sprache andere Treffer liefern kann.
    final cacheKey = SteamStoreSearchCacheKey(
      normalizedSearchTerm: normalizedSearchTerm,
      purchaseType: purchaseType,
      language: language,
      countryCode: countryCode,
    );
    final cachedEntry = await cache.read(cacheKey);
    final currentTime = now();

    if (cachedEntry != null && cachedEntry.expiresAt.isAfter(currentTime)) {
      return cachedEntry.suggestions;
    }

    try {
      final suggestions = await client.search(
        query: searchTerm,
        purchaseType: purchaseType,
        language: language,
        countryCode: countryCode,
      );
      final cacheDuration = suggestions.isEmpty
          ? emptyResultCacheDuration
          : resultCacheDuration;

      // Leere Ergebnisse werden kuerzer gecacht, weil Tippfehler oder neue
      // Steam-Eintraege sich schneller aendern koennen.
      await cache.write(
        cacheKey,
        SteamStoreSearchCacheEntry(
          suggestions: suggestions,
          expiresAt: currentTime.add(cacheDuration),
        ),
      );

      return suggestions;
    } catch (_) {
      // Autocomplete soll bei Netzproblemen nicht hart fehlschlagen. Abgelaufene
      // Cache-Daten sind dann besser als gar keine Vorschlaege.
      return cachedEntry?.suggestions ?? [];
    }
  }

  String _buildSearchTerm({
    required String query,
    required SteamPurchaseType purchaseType,
    required String? associatedGameName,
  }) {
    if (purchaseType != SteamPurchaseType.dlc) {
      return query;
    }

    final trimmedGameName = associatedGameName?.trim();

    if (trimmedGameName == null || trimmedGameName.isEmpty) {
      return query;
    }

    if (_normalizeSearchTerm(
      query,
    ).contains(_normalizeSearchTerm(trimmedGameName))) {
      return query;
    }

    return '$trimmedGameName $query';
  }

  String _normalizeSearchTerm(String value) {
    return normalizeSteamStoreSearchText(value);
  }
}

/// Stabiler Cache-Schluessel fuer Steam-Store-Suchergebnisse.
class SteamStoreSearchCacheKey {
  final String normalizedSearchTerm;
  final SteamPurchaseType purchaseType;
  final String language;
  final String countryCode;

  const SteamStoreSearchCacheKey({
    required this.normalizedSearchTerm,
    required this.purchaseType,
    required this.language,
    required this.countryCode,
  });

  String get storageKey {
    return jsonEncode({
      'query': normalizedSearchTerm,
      'type': purchaseType.storageValue,
      'language': language,
      'country': countryCode.toUpperCase(),
    });
  }
}

/// Cache-Wert inklusive Ablaufzeit.
class SteamStoreSearchCacheEntry {
  final List<SteamStoreSearchSuggestion> suggestions;
  final DateTime expiresAt;

  const SteamStoreSearchCacheEntry({
    required this.suggestions,
    required this.expiresAt,
  });
}

/// Abstraktion fuer den Suchcache.
abstract class SteamStoreSearchCache {
  Future<SteamStoreSearchCacheEntry?> read(SteamStoreSearchCacheKey key);

  Future<void> write(
    SteamStoreSearchCacheKey key,
    SteamStoreSearchCacheEntry entry,
  );
}

/// SQLite-Implementierung des Suchcaches.
class SqliteSteamStoreSearchCache implements SteamStoreSearchCache {
  static const String tableName = 'steam_store_search_cache';

  @override
  Future<SteamStoreSearchCacheEntry?> read(SteamStoreSearchCacheKey key) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      tableName,
      columns: ['suggestions_json', 'expires_at'],
      where: 'query_key = ?',
      whereArgs: [key.storageKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _entryFromMap(rows.single);
  }

  @override
  Future<void> write(
    SteamStoreSearchCacheKey key,
    SteamStoreSearchCacheEntry entry,
  ) async {
    final db = await AppDatabase.instance;
    await db.insert(tableName, {
      'query_key': key.storageKey,
      'suggestions_json': jsonEncode(
        entry.suggestions.map((suggestion) => suggestion.toJson()).toList(),
      ),
      'expires_at': entry.expiresAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  SteamStoreSearchCacheEntry? _entryFromMap(Map<String, Object?> map) {
    try {
      final decoded = jsonDecode(map['suggestions_json'] as String);

      if (decoded is! List<Object?>) {
        return null;
      }

      return SteamStoreSearchCacheEntry(
        suggestions: decoded
            .whereType<Map<Object?, Object?>>()
            .map(
              (suggestion) => SteamStoreSearchSuggestion.fromJson(
                suggestion.cast<String, Object?>(),
              ),
            )
            .toList(growable: false),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          map['expires_at'] as int,
        ),
      );
    } catch (_) {
      // Defekte Cache-Eintraege werden ignoriert; die naechste erfolgreiche
      // Suche schreibt den Eintrag neu.
      return null;
    }
  }
}
