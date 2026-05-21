import '../models/steam_purchase.dart';

class SteamStatistics {
  final List<SteamPurchase> purchases;

  const SteamStatistics(this.purchases);

  double get totalSpent {
    return purchases.fold(0, (sum, purchase) => sum + purchase.price);
  }

  int get totalGames {
    return purchases.length;
  }

  double? get averageDiscount {
    final discounts = purchases
        .map((purchase) => purchase.discount)
        .whereType<double>()
        .toList();

    if (discounts.isEmpty) {
      return null;
    }

    final sum = discounts.fold(0.0, (a, b) => a + b);
    return sum / discounts.length;
  }

  Map<int, double> get spendingByYear {
    final result = <int, double>{};

    for (final purchase in purchases) {
      result[purchase.year] = (result[purchase.year] ?? 0) + purchase.price;
    }

    return result;
  }
}
