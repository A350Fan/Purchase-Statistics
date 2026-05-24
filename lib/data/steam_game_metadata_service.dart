import '../models/steam_game_metadata.dart';
import '../models/steam_purchase.dart';
import 'steam_game_metadata_client.dart';
import 'steam_game_metadata_repository.dart';

class SteamGameMetadataRefreshResult {
  final int attempted;
  final int refreshed;
  final int skipped;
  final int failed;

  const SteamGameMetadataRefreshResult({
    required this.attempted,
    required this.refreshed,
    required this.skipped,
    required this.failed,
  });
}

class SteamGameMetadataService {
  final SteamGameMetadataClient client;
  final SteamGameMetadataRepository repository;

  SteamGameMetadataService({
    SteamGameMetadataClient? client,
    SteamGameMetadataRepository? repository,
  }) : client = client ?? HttpSteamGameMetadataClient(),
       repository = repository ?? SteamGameMetadataRepository();

  Future<SteamGameMetadata?> getMetadata(int steamAppId) {
    return repository.getMetadata(steamAppId);
  }

  Future<SteamGameMetadata?> refreshMetadata({
    required int steamAppId,
    required String language,
    required String countryCode,
  }) async {
    final metadata = await client.fetchMetadata(
      steamAppId: steamAppId,
      language: language,
      countryCode: countryCode,
    );

    if (metadata == null) {
      return null;
    }

    await repository.upsertMetadata(metadata);

    return metadata;
  }

  Future<SteamGameMetadata?> refreshMetadataForPurchase({
    required SteamPurchase purchase,
    required String language,
    required String countryCode,
  }) async {
    final steamAppId = purchase.steamAppId;

    if (steamAppId == null) {
      return null;
    }

    return refreshMetadata(
      steamAppId: steamAppId,
      language: language,
      countryCode: countryCode,
    );
  }

  Future<SteamGameMetadataRefreshResult> refreshMetadataForPurchases({
    required Iterable<SteamPurchase> purchases,
    required String language,
    required String countryCode,
    bool onlyMissing = false,
  }) async {
    final steamAppIds =
        purchases
            .map((purchase) => purchase.steamAppId)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    var attempted = 0;
    var refreshed = 0;
    var skipped = 0;
    var failed = 0;

    for (final steamAppId in steamAppIds) {
      if (onlyMissing && await repository.getMetadata(steamAppId) != null) {
        skipped++;
        continue;
      }

      attempted++;

      try {
        final metadata = await refreshMetadata(
          steamAppId: steamAppId,
          language: language,
          countryCode: countryCode,
        );

        if (metadata == null) {
          failed++;
        } else {
          refreshed++;
        }
      } catch (_) {
        failed++;
      }
    }

    return SteamGameMetadataRefreshResult(
      attempted: attempted,
      refreshed: refreshed,
      skipped: skipped,
      failed: failed,
    );
  }
}
