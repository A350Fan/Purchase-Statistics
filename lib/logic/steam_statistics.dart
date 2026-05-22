import '../models/steam_purchase.dart';

class SteamStatistics {
  final List<SteamPurchase> purchases;

  const SteamStatistics(this.purchases);

  double get totalSpent {
    return purchases.fold(0.0, (sum, purchase) => sum + purchase.price);
  }

  int get totalGames {
    return purchases.length;
  }

  double get totalOriginalPrice {
    return purchases.fold(
      0.0,
      (sum, purchase) => sum + (purchase.originalPrice ?? purchase.price),
    );
  }

  double get totalSavings {
    return purchases.fold(0.0, (sum, purchase) {
      final originalPrice = purchase.originalPrice;

      if (originalPrice == null) {
        return sum;
      }

      return sum + (originalPrice - purchase.price);
    });
  }

  double? get averagePrice {
    if (purchases.isEmpty) {
      return null;
    }

    return totalSpent / purchases.length;
  }

  double? get averageOriginalPrice {
    final purchasesWithOriginalPrice = purchases
        .where((purchase) => purchase.originalPrice != null)
        .toList();

    if (purchasesWithOriginalPrice.isEmpty) {
      return null;
    }

    final sum = purchasesWithOriginalPrice.fold(
      0.0,
      (sum, purchase) => sum + purchase.originalPrice!,
    );

    return sum / purchasesWithOriginalPrice.length;
  }

  double? get averageSavings {
    final purchasesWithOriginalPrice = purchases
        .where((purchase) => purchase.originalPrice != null)
        .toList();

    if (purchasesWithOriginalPrice.isEmpty) {
      return null;
    }

    final sum = purchasesWithOriginalPrice.fold(0.0, (sum, purchase) {
      return sum + (purchase.originalPrice! - purchase.price);
    });

    return sum / purchasesWithOriginalPrice.length;
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

  SteamPurchase? get mostExpensivePurchase {
    if (purchases.isEmpty) {
      return null;
    }

    return purchases.reduce((current, next) {
      return next.price > current.price ? next : current;
    });
  }

  SteamPurchase? get cheapestPurchase {
    if (purchases.isEmpty) {
      return null;
    }

    return purchases.reduce((current, next) {
      return next.price < current.price ? next : current;
    });
  }

  SteamPurchase? get highestDiscountPurchase {
    final purchasesWithDiscount = purchases
        .where((purchase) => purchase.discount != null)
        .toList();

    if (purchasesWithDiscount.isEmpty) {
      return null;
    }

    return purchasesWithDiscount.reduce((current, next) {
      return next.discount! > current.discount! ? next : current;
    });
  }

  Map<int, double> get spendingByYear {
    final result = <int, double>{};

    for (final purchase in purchases) {
      result[purchase.year] = (result[purchase.year] ?? 0.0) + purchase.price;
    }

    return result;
  }

  Map<int, int> get purchasesByYear {
    final result = <int, int>{};

    for (final purchase in purchases) {
      result[purchase.year] = (result[purchase.year] ?? 0) + 1;
    }

    return result;
  }

  Map<int, double> get savingsByYear {
    final result = <int, double>{};

    for (final purchase in purchases) {
      final originalPrice = purchase.originalPrice;

      if (originalPrice == null) {
        continue;
      }

      result[purchase.year] =
          (result[purchase.year] ?? 0.0) + (originalPrice - purchase.price);
    }

    return result;
  }

  Map<int, double> spendingByQuarterForYear(int year) {
    final result = {
      1: 0.0,
      2: 0.0,
      3: 0.0,
      4: 0.0,
    };

    for (final purchase in purchases.where((purchase) => purchase.year == year)) {
      result[purchase.quarter] = result[purchase.quarter]! + purchase.price;
    }

    return result;
  }

  Map<int, int> purchasesByQuarterForYear(int year) {
    final result = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
    };

    for (final purchase in purchases.where((purchase) => purchase.year == year)) {
      result[purchase.quarter] = result[purchase.quarter]! + 1;
    }

    return result;
  }

  Map<int, double?> averageDiscountByQuarterForYear(int year) {
    final discountsByQuarter = <int, List<double>>{
      1: [],
      2: [],
      3: [],
      4: [],
    };

    for (final purchase in purchases.where((purchase) => purchase.year == year)) {
      final discount = purchase.discount;

      if (discount == null) {
        continue;
      }

      discountsByQuarter[purchase.quarter]!.add(discount);
    }

    return discountsByQuarter.map((quarter, discounts) {
      if (discounts.isEmpty) {
        return MapEntry(quarter, null);
      }

      final sum = discounts.fold(0.0, (a, b) => a + b);
      return MapEntry(quarter, sum / discounts.length);
    });
  }
}