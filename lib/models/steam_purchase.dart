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

enum SteamGameStatus {
  open,
  active,
  completed,
  endless,
  abandoned,
  archived;

  String get storageValue {
    return switch (this) {
      SteamGameStatus.open => 'open',
      SteamGameStatus.active => 'active',
      SteamGameStatus.completed => 'completed',
      SteamGameStatus.endless => 'endless',
      SteamGameStatus.abandoned => 'abandoned',
      SteamGameStatus.archived => 'archived',
    };
  }

  static SteamGameStatus? fromStorageValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return switch (normalized) {
      'open' || 'offen' || 'backlog' || 'not_started' => SteamGameStatus.open,
      'active' ||
      'aktiv' ||
      'started' ||
      'angefangen' ||
      'in_progress' => SteamGameStatus.active,
      'completed' ||
      'complete' ||
      'finished' ||
      'durchgespielt' ||
      'beaten' => SteamGameStatus.completed,
      'endless' || 'endlos' || 'endless_game' => SteamGameStatus.endless,
      'abandoned' || 'abgebrochen' || 'dropped' => SteamGameStatus.abandoned,
      'archived' ||
      'archive' ||
      'archiv' ||
      'archiviert' ||
      'old' ||
      'alt' => SteamGameStatus.archived,
      _ => null,
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
  final SteamGameStatus? gameStatus;
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
    this.gameStatus,
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
    final cleanedDlcTitle = cleanDlcNameForGame(
      gameName: gameName,
      dlcName: dlcTitle,
    );

    return '$gameName: $cleanedDlcTitle$editionSuffix';
  }

  static String cleanDlcNameForGame({
    required String gameName,
    required String dlcName,
  }) {
    final trimmedGameName = gameName.trim();
    final trimmedDlcName = dlcName.trim();

    if (trimmedGameName.isEmpty || trimmedDlcName.isEmpty) {
      return trimmedDlcName;
    }

    final gameNamePattern = trimmedGameName
        .split(RegExp(r'\s+'))
        .map(RegExp.escape)
        .join(r'\s+');
    final prefixMatch = RegExp(
      '^$gameNamePattern\\s*[:\\-\\u2013\\u2014]\\s*',
      caseSensitive: false,
    ).firstMatch(trimmedDlcName);

    if (prefixMatch == null) {
      return trimmedDlcName;
    }

    final cleanedDlcName = trimmedDlcName.substring(prefixMatch.end).trim();

    return cleanedDlcName.isEmpty ? trimmedDlcName : cleanedDlcName;
  }

  SteamPurchase copyWith({
    int? id,
    DateTime? purchaseDate,
    SteamPurchaseType? purchaseType,
    String? gameName,
    String? edition,
    String? dlcName,
    SteamGameStatus? gameStatus,
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
      gameStatus: gameStatus ?? this.gameStatus,
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
      'game_status': purchaseType == SteamPurchaseType.game
          ? gameStatus?.storageValue
          : null,
      'steam_app_id': steamAppId,
      'price': price,
      'original_price': originalPrice,
      'playtime_hours': playtimeHours,
      'note': note,
    };
  }

  factory SteamPurchase.fromMap(Map<String, Object?> map) {
    final purchaseType = _parsePurchaseType(map['purchase_type']);

    return SteamPurchase(
      id: map['id'] as int?,
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      purchaseType: purchaseType,
      gameName: map['game_name'] as String,
      edition: _nullableString(map['edition']),
      dlcName: _nullableString(map['dlc_name']),
      gameStatus: purchaseType == SteamPurchaseType.game
          ? SteamGameStatus.fromStorageValue(map['game_status'])
          : null,
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
