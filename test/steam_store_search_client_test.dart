// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_store_search_client.dart';
import 'package:purchase_statistics/models/steam_store_search_suggestion.dart';

void main() {
  group('SteamStoreSearchResponseParser', () {
    test('parses store search items without an API key response shape', () {
      final suggestions = SteamStoreSearchResponseParser.parse('''
        {
          "total": 2,
          "items": [
            {"id": 620, "type": "app", "name": "Portal 2"},
            {"id": 400, "name": "Portal"}
          ]
        }
        ''', fallbackItemType: SteamStoreItemType.game);

      expect(suggestions, hasLength(2));
      expect(suggestions.first.appId, 620);
      expect(suggestions.first.name, 'Portal 2');
      expect(suggestions.first.itemType, SteamStoreItemType.game);
    });

    test('ignores invalid entries and deduplicates names', () {
      final suggestions = SteamStoreSearchResponseParser.parse('''
        {
          "items": [
            {"id": 1, "name": "Portal 2"},
            {"id": 2, "name": " portal   2 "},
            {"id": 3},
            {"name": "Missing ID"}
          ]
        }
        ''', fallbackItemType: SteamStoreItemType.other);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.appId, 1);
      expect(suggestions.single.name, 'Portal 2');
    });

    test('deduplicates names that only differ by legal marks', () {
      final suggestions = SteamStoreSearchResponseParser.parse('''
        {
          "items": [
            {"id": 1, "name": "F1\\u00ae Manager 22"},
            {"id": 2, "name": "F1 Manager 22"}
          ]
        }
        ''', fallbackItemType: SteamStoreItemType.game);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.appId, 1);
      expect(suggestions.single.name, 'F1\u00ae Manager 22');
    });
  });
}
