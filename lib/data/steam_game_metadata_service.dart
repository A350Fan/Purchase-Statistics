// SPDX-License-Identifier: GPL-3.0-or-later
import '../models/steam_game_metadata.dart';
import '../models/steam_purchase.dart';
import 'resource_lifecycle.dart';
import 'steam_game_metadata_client.dart';
import 'steam_game_metadata_repository.dart';

/// Zaehlergebnis einer Metadaten-Aktualisierung ueber mehrere Kaeufe.
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

/// Koordiniert Steam-Metadaten zwischen HTTP-Client und lokalem Repository.
///
/// Widgets sprechen mit diesem Service statt direkt mit Client/Repository,
/// damit Retry-Regeln und "unavailable"-Caching zentral bleiben.
class SteamGameMetadataService implements DisposableResource {
  final SteamGameMetadataClient client;
  final SteamGameMetadataRepository repository;
  final Duration unavailableMetadataRetryDelay;
  final bool _ownsClient;

  SteamGameMetadataService({
    SteamGameMetadataClient? client,
    SteamGameMetadataRepository? repository,
    this.unavailableMetadataRetryDelay = const Duration(days: 7),
  }) : client = client ?? HttpSteamGameMetadataClient(),
       repository = repository ?? SteamGameMetadataRepository(),
       _ownsClient = client == null;

  @override
  void dispose() {
    if (!_ownsClient) {
      return;
    }

    disposeResource(client);
  }

  Future<SteamGameMetadata?> getMetadata(int steamAppId) {
    return repository.getMetadata(steamAppId);
  }

  Future<SteamGameMetadata?> refreshMetadata({
    required int steamAppId,
    required String language,
    required String countryCode,
  }) async {
    // Kuerzlich fehlgeschlagene App-IDs werden uebersprungen, um Steam und die
    // UI nicht mit wiederholten aussichtslosen Requests zu belasten.
    if (await repository.hasRecentUnavailableMetadata(
      steamAppId,
      retryAfter: unavailableMetadataRetryDelay,
    )) {
      return null;
    }

    final metadata = await client.fetchMetadata(
      steamAppId: steamAppId,
      language: language,
      countryCode: countryCode,
    );

    if (metadata == null) {
      // Ein valider HTTP-Request ohne Nutzdaten bedeutet: fuer diese App-ID gibt
      // es aktuell keine verwertbaren Metadaten.
      await repository.markMetadataUnavailable(steamAppId);
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

    if (!purchase.launcher.isSteam || steamAppId == null) {
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
            .where((purchase) => purchase.launcher.isSteam)
            .map((purchase) => purchase.steamAppId)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    // Die sortierte, deduplizierte Liste sorgt fuer stabile, testbare
    // Reihenfolge und vermeidet doppelte Requests fuer mehrere Kaeufe desselben
    // Spiels.
    var attempted = 0;
    var refreshed = 0;
    var skipped = 0;
    var failed = 0;

    for (final steamAppId in steamAppIds) {
      if (await repository.hasRecentUnavailableMetadata(
        steamAppId,
        retryAfter: unavailableMetadataRetryDelay,
      )) {
        skipped++;
        continue;
      }

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
