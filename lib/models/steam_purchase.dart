class SteamPurchase {
  final int? id;
  final DateTime purchaseDate;
  final String gameName;
  final double price;
  final double? originalPrice;
  final String? note;

  const SteamPurchase({
    this.id,
    required this.purchaseDate,
    required this.gameName,
    required this.price,
    this.originalPrice,
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
}