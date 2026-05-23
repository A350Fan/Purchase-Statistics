import '../models/steam_game_metadata.dart';
import '../models/steam_purchase.dart';
import 'steam_game_metadata_client.dart';
import 'steam_game_metadata_repository.dart';

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
}
