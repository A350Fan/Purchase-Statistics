import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_store_search_client.dart';
import 'package:purchase_statistics/data/steam_store_search_repository.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:purchase_statistics/models/steam_store_search_suggestion.dart';

void main() {
  group('SteamStoreSearchRepository', () {
    test('caches successful search results', () async {
      final now = DateTime(2026, 5, 23);
      final cache = _MemorySteamSearchCache();
      final client = _FakeSteamStoreSearchClient([
        const SteamStoreSearchSuggestion(appId: 620, name: 'Portal 2'),
      ]);
      final repository = SteamStoreSearchRepository(
        client: client,
        cache: cache,
        now: () => now,
      );

      final firstResult = await repository.search(
        query: 'Portal',
        purchaseType: SteamPurchaseType.game,
        language: 'german',
        countryCode: 'DE',
      );
      final secondResult = await repository.search(
        query: 'Portal',
        purchaseType: SteamPurchaseType.game,
        language: 'german',
        countryCode: 'DE',
      );

      expect(firstResult.single.name, 'Portal 2');
      expect(secondResult.single.name, 'Portal 2');
      expect(client.callCount, 1);
      expect(cache.writeCount, 1);
    });

    test('uses stale cache when online search fails', () async {
      final now = DateTime(2026, 5, 23);
      final cache = _MemorySteamSearchCache();
      final cacheKey = const SteamStoreSearchCacheKey(
        normalizedSearchTerm: 'portal',
        purchaseType: SteamPurchaseType.game,
        language: 'german',
        countryCode: 'DE',
      );
      await cache.write(
        cacheKey,
        SteamStoreSearchCacheEntry(
          suggestions: const [
            SteamStoreSearchSuggestion(appId: 400, name: 'Portal'),
          ],
          expiresAt: now.subtract(const Duration(days: 1)),
        ),
      );
      final repository = SteamStoreSearchRepository(
        client: _FakeSteamStoreSearchClient(const [], shouldThrow: true),
        cache: cache,
        now: () => now,
      );

      final result = await repository.search(
        query: 'Portal',
        purchaseType: SteamPurchaseType.game,
        language: 'german',
        countryCode: 'DE',
      );

      expect(result.single.name, 'Portal');
    });

    test('uses legal-mark-insensitive cache keys', () async {
      final cache = _MemorySteamSearchCache();
      final client = _FakeSteamStoreSearchClient([
        const SteamStoreSearchSuggestion(
          appId: 1708520,
          name: 'F1\u00ae Manager 22',
        ),
      ]);
      final repository = SteamStoreSearchRepository(
        client: client,
        cache: cache,
        now: () => DateTime(2026, 5, 23),
      );

      final firstResult = await repository.search(
        query: 'F1\u00ae Manager 22',
        purchaseType: SteamPurchaseType.game,
        language: 'german',
        countryCode: 'DE',
      );
      final secondResult = await repository.search(
        query: 'F1 Manager 22',
        purchaseType: SteamPurchaseType.game,
        language: 'german',
        countryCode: 'DE',
      );

      expect(firstResult.single.name, 'F1\u00ae Manager 22');
      expect(secondResult.single.name, 'F1\u00ae Manager 22');
      expect(client.callCount, 1);
      expect(cache.writeCount, 1);
    });

    test('combines DLC search with the associated game name', () async {
      final client = _FakeSteamStoreSearchClient([
        const SteamStoreSearchSuggestion(
          appId: 289070,
          name: 'Sid Meier\'s Civilization VI: Gathering Storm',
          itemType: SteamStoreItemType.dlc,
        ),
      ]);
      final repository = SteamStoreSearchRepository(
        client: client,
        cache: _MemorySteamSearchCache(),
        now: () => DateTime(2026, 5, 23),
      );

      await repository.search(
        query: 'storm',
        purchaseType: SteamPurchaseType.dlc,
        language: 'german',
        countryCode: 'DE',
        associatedGameName: 'Civilization VI',
      );

      expect(client.queries.single, 'Civilization VI storm');
    });
  });
}

class _FakeSteamStoreSearchClient implements SteamStoreSearchClient {
  final List<SteamStoreSearchSuggestion> suggestions;
  final bool shouldThrow;
  final List<String> queries = [];

  _FakeSteamStoreSearchClient(this.suggestions, {this.shouldThrow = false});

  int get callCount => queries.length;

  @override
  Future<List<SteamStoreSearchSuggestion>> search({
    required String query,
    required SteamPurchaseType purchaseType,
    required String language,
    required String countryCode,
  }) async {
    queries.add(query);

    if (shouldThrow) {
      throw const SteamStoreSearchException();
    }

    return suggestions;
  }
}

class SteamStoreSearchException implements Exception {
  const SteamStoreSearchException();
}

class _MemorySteamSearchCache implements SteamStoreSearchCache {
  final Map<String, SteamStoreSearchCacheEntry> entries = {};
  int writeCount = 0;

  @override
  Future<SteamStoreSearchCacheEntry?> read(SteamStoreSearchCacheKey key) async {
    return entries[key.storageKey];
  }

  @override
  Future<void> write(
    SteamStoreSearchCacheKey key,
    SteamStoreSearchCacheEntry entry,
  ) async {
    writeCount++;
    entries[key.storageKey] = entry;
  }
}
