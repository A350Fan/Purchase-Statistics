// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_app_linking_service.dart';
import 'package:purchase_statistics/data/steam_store_search_repository.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:purchase_statistics/models/steam_store_search_suggestion.dart';

void main() {
  group('SteamAppLinkingService', () {
    test('finds high-confidence exact game matches', () async {
      final source = _FakeSteamStoreSearchSource({
        'Portal 2': const [
          SteamStoreSearchSuggestion(
            appId: 620,
            name: 'Portal 2',
            itemType: SteamStoreItemType.game,
          ),
        ],
      });
      final service = SteamAppLinkingService(searchSource: source);

      final candidates = await service.findCandidates(
        purchases: [
          SteamPurchase(
            id: 1,
            purchaseDate: DateTime(2026, 5, 24),
            gameName: 'Portal 2',
            price: 9.99,
          ),
        ],
        language: 'german',
        countryCode: 'DE',
      );

      expect(candidates.single.suggestion.appId, 620);
      expect(candidates.single.isHighConfidence, isTrue);
    });

    test(
      'matches DLC suggestions after removing the base-game prefix',
      () async {
        final source = _FakeSteamStoreSearchSource({
          'Peer Review': const [
            SteamStoreSearchSuggestion(
              appId: 644,
              name: 'Portal 2: Peer Review',
              itemType: SteamStoreItemType.dlc,
            ),
          ],
        });
        final service = SteamAppLinkingService(searchSource: source);

        final candidates = await service.findCandidates(
          purchases: [
            SteamPurchase(
              id: 2,
              purchaseDate: DateTime(2026, 5, 24),
              purchaseType: SteamPurchaseType.dlc,
              gameName: 'Portal 2',
              dlcName: 'Peer Review',
              price: 0,
            ),
          ],
          language: 'english',
          countryCode: 'US',
        );

        expect(candidates.single.suggestion.appId, 644);
        expect(source.associatedGameNames.single, 'Portal 2');
        expect(candidates.single.isHighConfidence, isTrue);
      },
    );

    test('skips purchases that are already linked or not persisted', () async {
      final source = _FakeSteamStoreSearchSource({
        'Portal 2': const [
          SteamStoreSearchSuggestion(appId: 620, name: 'Portal 2'),
        ],
      });
      final service = SteamAppLinkingService(searchSource: source);

      final candidates = await service.findCandidates(
        purchases: [
          SteamPurchase(
            purchaseDate: DateTime(2026, 5, 24),
            gameName: 'Portal 2',
            price: 9.99,
          ),
          SteamPurchase(
            id: 2,
            purchaseDate: DateTime(2026, 5, 24),
            gameName: 'Portal 2',
            steamAppId: 620,
            price: 9.99,
          ),
        ],
        language: 'german',
        countryCode: 'DE',
      );

      expect(candidates, isEmpty);
      expect(source.queries, isEmpty);
    });
  });
}

class _FakeSteamStoreSearchSource implements SteamStoreSearchSource {
  final Map<String, List<SteamStoreSearchSuggestion>> suggestionsByQuery;
  final List<String> queries = [];
  final List<String?> associatedGameNames = [];

  _FakeSteamStoreSearchSource(this.suggestionsByQuery);

  @override
  Future<List<SteamStoreSearchSuggestion>> search({
    required String query,
    required SteamPurchaseType purchaseType,
    required String language,
    required String countryCode,
    String? associatedGameName,
  }) async {
    queries.add(query);
    associatedGameNames.add(associatedGameName);

    return suggestionsByQuery[query] ?? const [];
  }
}
