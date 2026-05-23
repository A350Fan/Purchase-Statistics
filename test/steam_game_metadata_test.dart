import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/models/steam_game_metadata.dart';

void main() {
  group('SteamGameMetadata', () {
    test('matches collection metadata rules case-insensitively', () {
      const metadata = SteamGameMetadata(
        steamAppId: 620,
        name: 'Portal 2',
        genres: ['Action', 'Adventure'],
        tags: ['Puzzle Platformer'],
        developers: ['Valve'],
        publishers: ['Valve'],
      );

      expect(
        metadata.matchesRule(
          const SteamCollectionMetadataRule(
            field: SteamMetadataField.genre,
            value: ' action ',
          ),
        ),
        isTrue,
      );
      expect(
        metadata.matchesRule(
          const SteamCollectionMetadataRule(
            field: SteamMetadataField.tag,
            value: 'puzzle   platformer',
          ),
        ),
        isTrue,
      );
      expect(
        metadata.matchesRule(
          const SteamCollectionMetadataRule(
            field: SteamMetadataField.developer,
            value: 'Valve',
          ),
        ),
        isTrue,
      );
    });

    test('does not match unrelated metadata rules', () {
      const metadata = SteamGameMetadata(
        steamAppId: 620,
        name: 'Portal 2',
        genres: ['Action'],
        tags: ['Puzzle'],
      );

      expect(
        metadata.matchesRule(
          const SteamCollectionMetadataRule(
            field: SteamMetadataField.publisher,
            value: 'Bethesda',
          ),
        ),
        isFalse,
      );
    });
  });
}
