enum SteamPurchaseType {
  game,
  dlc;

  String get storageValue {
    return switch (this) {
      SteamPurchaseType.game => 'game',
      SteamPurchaseType.dlc => 'dlc',
    };
  }
}

class SteamPurchase {
  final int? id;
  final DateTime purchaseDate;
  final SteamPurchaseType purchaseType;
  final String gameName;
  final String? edition;
  final String? dlcName;
  final int? steamAppId;
  final double price;
  final double? originalPrice;
  final double? playtimeHours;
  final String? note;

  const SteamPurchase({
    this.id,
    required this.purchaseDate,
    this.purchaseType = SteamPurchaseType.game,
    required this.gameName,
    this.edition,
    this.dlcName,
    this.steamAppId,
    required this.price,
    this.originalPrice,
    this.playtimeHours,
    this.note,
  });

  int get year => purchaseDate.year;

  int get quarter {
    return ((purchaseDate.month - 1) ~/ 3) + 1;
  }

  double? get discount {
    if (originalPrice == null || originalPrice == 0) {
      return null;
    }

    return 1 - (price / originalPrice!);
  }

  String get displayName {
    final editionSuffix = edition == null || edition!.trim().isEmpty
        ? ''
        : ' (${edition!.trim()})';

    if (purchaseType != SteamPurchaseType.dlc) {
      return '$gameName$editionSuffix';
    }

    final dlcTitle = dlcName == null || dlcName!.trim().isEmpty
        ? 'DLC'
        : dlcName!.trim();

    return '$gameName: $dlcTitle$editionSuffix';
  }

  SteamPurchase copyWith({
    int? id,
    DateTime? purchaseDate,
    SteamPurchaseType? purchaseType,
    String? gameName,
    String? edition,
    String? dlcName,
    int? steamAppId,
    double? price,
    double? originalPrice,
    double? playtimeHours,
    String? note,
  }) {
    return SteamPurchase(
      id: id ?? this.id,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseType: purchaseType ?? this.purchaseType,
      gameName: gameName ?? this.gameName,
      edition: edition ?? this.edition,
      dlcName: dlcName ?? this.dlcName,
      steamAppId: steamAppId ?? this.steamAppId,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      playtimeHours: playtimeHours ?? this.playtimeHours,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'purchase_date': purchaseDate.toIso8601String(),
      'purchase_type': purchaseType.storageValue,
      'game_name': gameName,
      'edition': edition,
      'dlc_name': dlcName,
      'steam_app_id': steamAppId,
      'price': price,
      'original_price': originalPrice,
      'playtime_hours': playtimeHours,
      'note': note,
    };
  }

  factory SteamPurchase.fromMap(Map<String, Object?> map) {
    return SteamPurchase(
      id: map['id'] as int?,
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      purchaseType: _parsePurchaseType(map['purchase_type']),
      gameName: map['game_name'] as String,
      edition: _nullableString(map['edition']),
      dlcName: _nullableString(map['dlc_name']),
      steamAppId: map['steam_app_id'] as int?,
      price: (map['price'] as num).toDouble(),
      originalPrice: map['original_price'] == null
          ? null
          : (map['original_price'] as num).toDouble(),
      playtimeHours: map['playtime_hours'] == null
          ? null
          : (map['playtime_hours'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }

  static SteamPurchaseType _parsePurchaseType(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();

    return switch (normalized) {
      'dlc' ||
      'downloadable_content' ||
      'addon' ||
      'add_on' => SteamPurchaseType.dlc,
      _ => SteamPurchaseType.game,
    };
  }

  static String? _nullableString(Object? value) {
    final stringValue = value as String?;

    if (stringValue == null || stringValue.trim().isEmpty) {
      return null;
    }

    return stringValue;
  }
}
