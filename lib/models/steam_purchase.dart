class SteamPurchase {
  final int? id;
  final DateTime purchaseDate;
  final String gameName;
  final double price;
  final double? originalPrice;
  final double? playtimeHours;
  final String? note;

  const SteamPurchase({
    this.id,
    required this.purchaseDate,
    required this.gameName,
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

  double? get pricePerHour {
    final hours = playtimeHours;

    if (hours == null || hours <= 0) {
      return null;
    }

    return price / hours;
  }

  SteamPurchase copyWith({
    int? id,
    DateTime? purchaseDate,
    String? gameName,
    double? price,
    double? originalPrice,
    double? playtimeHours,
    String? note,
  }) {
    return SteamPurchase(
      id: id ?? this.id,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      gameName: gameName ?? this.gameName,
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
      'game_name': gameName,
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
      gameName: map['game_name'] as String,
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
}
