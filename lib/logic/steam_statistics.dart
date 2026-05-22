import '../models/steam_purchase.dart';

class AnnualStatistics {
  final int year;
  final double spending;
  final double? averageDiscount;
  final double cumulativeSpending;

  const AnnualStatistics({
    required this.year,
    required this.spending,
    required this.averageDiscount,
    required this.cumulativeSpending,
  });
}

class AnnualStatisticsSummary {
  final double averageSpending;
  final double totalSpending;
  final double totalOriginalPrice;
  final double? averageDiscount;

  const AnnualStatisticsSummary({
    required this.averageSpending,
    required this.totalSpending,
    required this.totalOriginalPrice,
    required this.averageDiscount,
  });
}

class QuarterlyStatistics {
  final int quarter;
  final double spending;
  final double? averageDiscount;
  final double cumulativeSpending;

  const QuarterlyStatistics({
    required this.quarter,
    required this.spending,
    required this.averageDiscount,
    required this.cumulativeSpending,
  });
}

class QuarterlyStatisticsSummary {
  final int year;
  final double actualSpending;
  final double projectedSpending;
  final double averageQuarterSpending;
  final double? averageDiscount;
  final bool isProjected;

  const QuarterlyStatisticsSummary({
    required this.year,
    required this.actualSpending,
    required this.projectedSpending,
    required this.averageQuarterSpending,
    required this.averageDiscount,
    required this.isProjected,
  });
}

class SteamStatistics {
  final List<SteamPurchase> purchases;
  final DateTime currentDate;

  SteamStatistics(this.purchases, {DateTime? currentDate})
    : currentDate = currentDate == null
          ? DateTime.now()
          : DateTime(currentDate.year, currentDate.month, currentDate.day);

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

  List<int> get years {
    if (purchases.isEmpty) {
      return [];
    }

    var firstYear = purchases.first.year;
    var lastYear = purchases.first.year;

    for (final purchase in purchases.skip(1)) {
      if (purchase.year < firstYear) {
        firstYear = purchase.year;
      }

      if (purchase.year > lastYear) {
        lastYear = purchase.year;
      }
    }

    if (currentDate.year > lastYear) {
      lastYear = currentDate.year;
    }

    return [for (var year = firstYear; year <= lastYear; year++) year];
  }

  AnnualStatisticsSummary get annualSummary {
    final yearsWithData = years;

    return AnnualStatisticsSummary(
      averageSpending: yearsWithData.isEmpty
          ? 0
          : totalSpent / yearsWithData.length,
      totalSpending: totalSpent,
      totalOriginalPrice: totalOriginalPrice,
      averageDiscount: averageDiscount,
    );
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

  Map<int, double?> get averageDiscountByYear {
    final discountsByYear = <int, List<double>>{};

    for (final purchase in purchases) {
      final discount = purchase.discount;

      if (discount == null) {
        continue;
      }

      discountsByYear.putIfAbsent(purchase.year, () => []).add(discount);
    }

    final result = <int, double?>{};

    for (final year in years) {
      final discounts = discountsByYear[year];

      if (discounts == null || discounts.isEmpty) {
        result[year] = null;
        continue;
      }

      result[year] =
          discounts.fold(0.0, (sum, discount) => sum + discount) /
          discounts.length;
    }

    return result;
  }

  List<AnnualStatistics> get annualStatistics {
    final rows = <AnnualStatistics>[];
    final yearlySpending = spendingByYear;
    final yearlyDiscount = averageDiscountByYear;
    var cumulativeSpending = 0.0;

    for (final year in years) {
      final spending = yearlySpending[year] ?? 0.0;
      cumulativeSpending += spending;

      rows.add(
        AnnualStatistics(
          year: year,
          spending: spending,
          averageDiscount: yearlyDiscount[year],
          cumulativeSpending: cumulativeSpending,
        ),
      );
    }

    return rows;
  }

  Map<int, double> spendingByQuarterForYear(int year) {
    final result = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};

    for (final purchase in purchases.where(
      (purchase) => purchase.year == year,
    )) {
      result[purchase.quarter] = result[purchase.quarter]! + purchase.price;
    }

    return result;
  }

  Map<int, int> purchasesByQuarterForYear(int year) {
    final result = {1: 0, 2: 0, 3: 0, 4: 0};

    for (final purchase in purchases.where(
      (purchase) => purchase.year == year,
    )) {
      result[purchase.quarter] = result[purchase.quarter]! + 1;
    }

    return result;
  }

  Map<int, double?> averageDiscountByQuarterForYear(int year) {
    final discountsByQuarter = <int, List<double>>{1: [], 2: [], 3: [], 4: []};

    for (final purchase in purchases.where(
      (purchase) => purchase.year == year,
    )) {
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

  List<QuarterlyStatistics> quarterlyStatisticsForYear(int year) {
    final rows = <QuarterlyStatistics>[];
    final quarterSpending = spendingByQuarterForYear(year);
    final quarterDiscount = averageDiscountByQuarterForYear(year);
    var cumulativeSpending = 0.0;

    for (var quarter = 1; quarter <= 4; quarter++) {
      final spending = quarterSpending[quarter] ?? 0.0;
      cumulativeSpending += spending;

      rows.add(
        QuarterlyStatistics(
          quarter: quarter,
          spending: spending,
          averageDiscount: quarterDiscount[quarter],
          cumulativeSpending: cumulativeSpending,
        ),
      );
    }

    return rows;
  }

  QuarterlyStatisticsSummary quarterlySummaryForYear(int year) {
    final actualSpending = spendingByQuarterForYear(
      year,
    ).values.fold(0.0, (sum, spending) => sum + spending);
    final isProjected = year == currentDate.year;
    final projectedSpending = isProjected
        ? _projectCurrentYearSpending(actualSpending)
        : actualSpending;
    final discounts = purchases
        .where((purchase) => purchase.year == year)
        .map((purchase) => purchase.discount)
        .whereType<double>()
        .toList();

    return QuarterlyStatisticsSummary(
      year: year,
      actualSpending: actualSpending,
      projectedSpending: projectedSpending,
      averageQuarterSpending: projectedSpending / 4,
      averageDiscount: discounts.isEmpty
          ? null
          : discounts.fold(0.0, (sum, discount) => sum + discount) /
                discounts.length,
      isProjected: isProjected,
    );
  }

  double _projectCurrentYearSpending(double spending) {
    final elapsedDays = _elapsedDaysInYear(currentDate);
    final daysInYear = _daysInYear(currentDate.year);

    return spending / elapsedDays * daysInYear;
  }

  int _elapsedDaysInYear(DateTime date) {
    final yearStart = DateTime.utc(date.year);
    final currentDay = DateTime.utc(date.year, date.month, date.day);

    return currentDay.difference(yearStart).inDays + 1;
  }

  int _daysInYear(int year) {
    return DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays;
  }
}
