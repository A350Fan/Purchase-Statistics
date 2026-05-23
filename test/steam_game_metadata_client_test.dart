import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_game_metadata_client.dart';

void main() {
  group('SteamGameMetadataResponseParser', () {
    test('parses Steam appdetails metadata', () {
      final metadata = SteamGameMetadataResponseParser.parse('''
        {
          "620": {
            "success": true,
            "data": {
              "steam_appid": 620,
              "name": "Portal 2",
              "developers": ["Valve"],
              "publishers": ["Valve"],
              "genres": [
                {"id": "1", "description": "Action"},
                {"id": "25", "description": "Adventure"}
              ],
              "categories": [
                {"id": 1, "description": "Single-player"},
                {"id": 9, "description": "Co-op"}
              ],
              "tags": {
                "Puzzle": 256,
                "Sci-fi": 128
              }
            }
          }
        }
      ''', requestedSteamAppId: 620);

      expect(metadata, isNotNull);
      expect(metadata!.steamAppId, 620);
      expect(metadata.name, 'Portal 2');
      expect(metadata.genres, ['Action', 'Adventure']);
      expect(metadata.tags, ['Single-player', 'Co-op', 'Puzzle', 'Sci-fi']);
      expect(metadata.developers, ['Valve']);
      expect(metadata.publishers, ['Valve']);
    });

    test('returns null for failed appdetails response', () {
      final metadata = SteamGameMetadataResponseParser.parse('''
        {
          "620": {
            "success": false
          }
        }
      ''', requestedSteamAppId: 620);

      expect(metadata, isNull);
    });
  });
}
