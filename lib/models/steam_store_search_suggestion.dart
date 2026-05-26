import 'steam_purchase.dart';

/// Typ eines Suchtreffers aus dem Steam Store.
enum SteamStoreItemType {
  game,
  dlc,
  other;

  String get storageValue {
    return switch (this) {
      SteamStoreItemType.game => 'game',
      SteamStoreItemType.dlc => 'dlc',
      SteamStoreItemType.other => 'other',
    };
  }

  static SteamStoreItemType fromStorage(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'game' => SteamStoreItemType.game,
      'dlc' => SteamStoreItemType.dlc,
      _ => SteamStoreItemType.other,
    };
  }

  static SteamStoreItemType fromPurchaseType(SteamPurchaseType purchaseType) {
    return switch (purchaseType) {
      SteamPurchaseType.game => SteamStoreItemType.game,
      SteamPurchaseType.dlc => SteamStoreItemType.dlc,
    };
  }
}

/// Vereinfachter Steam-Store-Treffer fuer Autocomplete und App-Verknuepfung.
class SteamStoreSearchSuggestion {
  final int appId;
  final String name;
  final SteamStoreItemType itemType;

  const SteamStoreSearchSuggestion({
    required this.appId,
    required this.name,
    this.itemType = SteamStoreItemType.other,
  });

  /// Serialisiert den Treffer fuer den lokalen Suchcache.
  Map<String, Object?> toJson() {
    return {'app_id': appId, 'name': name, 'item_type': itemType.storageValue};
  }

  /// Baut einen Treffer aus dem JSON, das im Cache gespeichert wurde.
  factory SteamStoreSearchSuggestion.fromJson(Map<String, Object?> json) {
    return SteamStoreSearchSuggestion(
      appId: (json['app_id'] as num).toInt(),
      name: json['name'] as String,
      itemType: SteamStoreItemType.fromStorage(json['item_type']),
    );
  }
}
