import '../models/steam_purchase.dart';

class AnnualStatistics {
  final int year;
  final double spending;
  final double? averageDiscount;
  final double cumulativeSpending;
  final double playtimeHours;
  final double? pricePerHour;

  const AnnualStatistics({
    required this.year,
    required this.spending,
    required this.averageDiscount,
    required this.cumulativeSpending,
    required this.playtimeHours,
    required this.pricePerHour,
  });
}

class AnnualStatisticsSummary {
  final double averageSpending;
  final double totalSpending;
  final double totalOriginalPrice;
  final double totalPlaytimeHours;
  final double? averageDiscount;
  final double? pricePerHour;

  const AnnualStatisticsSummary({
    required this.averageSpending,
    required this.totalSpending,
    required this.totalOriginalPrice,
    required this.totalPlaytimeHours,
    required this.averageDiscount,
    required this.pricePerHour,
  });
}

class QuarterlyStatistics {
  final int quarter;
  final double spending;
  final double? averageDiscount;
  final double cumulativeSpending;
  final double playtimeHours;
  final double? pricePerHour;

  const QuarterlyStatistics({
    required this.quarter,
    required this.spending,
    required this.averageDiscount,
    required this.cumulativeSpending,
    required this.playtimeHours,
    required this.pricePerHour,
  });
}

class QuarterlyStatisticsSummary {
  final int year;
  final double actualSpending;
  final double projectedSpending;
  final double averageQuarterSpending;
  final double? averageDiscount;
  final double totalPlaytimeHours;
  final double? pricePerHour;
  final bool isProjected;

  const QuarterlyStatisticsSummary({
    required this.year,
    required this.actualSpending,
    required this.projectedSpending,
    required this.averageQuarterSpending,
    required this.averageDiscount,
    required this.totalPlaytimeHours,
    required this.pricePerHour,
    required this.isProjected,
  });
}

class SteamStatistics {
  final List<SteamPurchase> purchases;
  final DateTime currentDate;

  final Map<int, _QuarterAggregate> _quarterAggregatesByYear = {};

  late final _StatisticsAggregate _aggregate = _buildAggregate();
  late final Set<String> _gameNamesWithTrackedPlaytime =
      _aggregate.gameNamesWithTrackedPlaytime;
  late final Map<String, double> _dlcSpendingByGameName =
      _aggregate.dlcSpendingByGameName;
  late final Map<int, double> _spendingByYear = _aggregate.spendingByYear;
  late final Map<int, double> _playtimeByYear = _aggregate.playtimeByYear;
  late final Map<int, double> _spendingWithPlaytimeByYear =
      _aggregate.spendingWithPlaytimeByYear;
  late final Map<int, double?> _pricePerHourByYear = _buildPricePerHourByYear();

  late final double totalSpent = _aggregate.totalSpent;
  late final int totalGames = _aggregate.totalGames;
  late final int totalDlcs = _aggregate.totalDlcs;
  late final double totalOriginalPrice = _aggregate.totalOriginalPrice;
  late final double totalPlaytimeHours = _aggregate.totalPlaytimeHours;
  late final double totalSpentWithPlaytime = _aggregate.totalSpentWithPlaytime;
  late final double? pricePerHour = _pricePerHour(
    totalSpentWithPlaytime,
    totalPlaytimeHours,
  );
  late final double? averageDiscount = _aggregate.averageDiscount;
  late final List<int> years = _buildYears();
  late final Map<int, double?> _averageDiscountByYear = _aggregate
      .averageDiscountByYear(years);
  late final AnnualStatisticsSummary annualSummary = _buildAnnualSummary();
  late final List<AnnualStatistics> annualStatistics = _buildAnnualStatistics();

  SteamStatistics(this.purchases, {DateTime? currentDate})
    : currentDate = currentDate == null
          ? DateTime.now()
          : DateTime(currentDate.year, currentDate.month, currentDate.day);

  int get totalPurchases {
    return purchases.length;
  }

  double priceIncludingLinkedDlcsForPurchase(SteamPurchase purchase) {
    if (purchase.purchaseType != SteamPurchaseType.game) {
      return purchase.price;
    }

    return purchase.price +
        (_dlcSpendingByGameName[_gameNameKey(purchase.gameName)] ?? 0.0);
  }

  double? pricePerHourForPurchase(SteamPurchase purchase) {
    final hours = purchase.playtimeHours;

    if (hours == null || hours <= 0) {
      return null;
    }

    return priceIncludingLinkedDlcsForPurchase(purchase) / hours;
  }

  List<QuarterlyStatistics> quarterlyStatisticsForYear(int year) {
    final rows = <QuarterlyStatistics>[];
    final aggregate = _quarterAggregateForYear(year);
    var cumulativeSpending = 0.0;

    for (var quarter = 1; quarter <= 4; quarter++) {
      final spending = aggregate.spending[quarter];
      cumulativeSpending += spending;

      rows.add(
        QuarterlyStatistics(
          quarter: quarter,
          spending: spending,
          averageDiscount: aggregate.averageDiscountForQuarter(quarter),
          cumulativeSpending: cumulativeSpending,
          playtimeHours: aggregate.playtime[quarter],
          pricePerHour: aggregate.pricePerHourForQuarter(quarter),
        ),
      );
    }

    return rows;
  }

  QuarterlyStatisticsSummary quarterlySummaryForYear(int year) {
    final aggregate = _quarterAggregateForYear(year);
    final actualSpending = aggregate.actualSpending;
    final isProjected = year == currentDate.year;
    final projectedSpending = isProjected
        ? _projectCurrentYearSpending(actualSpending)
        : actualSpending;

    return QuarterlyStatisticsSummary(
      year: year,
      actualSpending: actualSpending,
      projectedSpending: projectedSpending,
      averageQuarterSpending: projectedSpending / 4,
      averageDiscount: aggregate.averageDiscount,
      totalPlaytimeHours: aggregate.totalPlaytime,
      pricePerHour: _pricePerHour(
        aggregate.totalTrackedSpending,
        aggregate.totalPlaytime,
      ),
      isProjected: isProjected,
    );
  }

  AnnualStatisticsSummary _buildAnnualSummary() {
    return AnnualStatisticsSummary(
      averageSpending: years.isEmpty ? 0 : totalSpent / years.length,
      totalSpending: totalSpent,
      totalOriginalPrice: totalOriginalPrice,
      totalPlaytimeHours: totalPlaytimeHours,
      averageDiscount: averageDiscount,
      pricePerHour: pricePerHour,
    );
  }

  List<AnnualStatistics> _buildAnnualStatistics() {
    final rows = <AnnualStatistics>[];
    var cumulativeSpending = 0.0;

    for (final year in years) {
      final spending = _spendingByYear[year] ?? 0.0;
      cumulativeSpending += spending;

      rows.add(
        AnnualStatistics(
          year: year,
          spending: spending,
          averageDiscount: _averageDiscountByYear[year],
          cumulativeSpending: cumulativeSpending,
          playtimeHours: _playtimeByYear[year] ?? 0.0,
          pricePerHour: _pricePerHourByYear[year],
        ),
      );
    }

    return List.unmodifiable(rows);
  }

  List<int> _buildYears() {
    final firstYear = _aggregate.firstYear;
    final lastPurchaseYear = _aggregate.lastYear;

    if (firstYear == null || lastPurchaseYear == null) {
      return const [];
    }

    var lastYear = lastPurchaseYear;

    if (currentDate.year > lastYear) {
      lastYear = currentDate.year;
    }

    return List.unmodifiable([
      for (var year = firstYear; year <= lastYear; year++) year,
    ]);
  }

  _StatisticsAggregate _buildAggregate() {
    final aggregate = _StatisticsAggregate();
    final untrackedDlcSpendingByYearAndGameName =
        <({int year, String gameNameKey}), double>{};

    for (final purchase in purchases) {
      final year = purchase.year;
      final gameNameKey = _gameNameKey(purchase.gameName);
      final hasPlaytime = _hasPlaytime(purchase);

      aggregate.addYear(year);
      aggregate.totalSpent += purchase.price;
      aggregate.totalOriginalPrice += purchase.originalPrice ?? purchase.price;
      aggregate.spendingByYear[year] =
          (aggregate.spendingByYear[year] ?? 0.0) + purchase.price;
      aggregate.discountsByYear
          .putIfAbsent(year, () => _DiscountAggregate())
          .add(purchase);
      aggregate.totalDiscount.add(purchase);

      switch (purchase.purchaseType) {
        case SteamPurchaseType.game:
          aggregate.totalGames++;

          if (hasPlaytime) {
            aggregate.gameNamesWithTrackedPlaytime.add(gameNameKey);
          }

        case SteamPurchaseType.dlc:
          aggregate.totalDlcs++;
          aggregate.dlcSpendingByGameName[gameNameKey] =
              (aggregate.dlcSpendingByGameName[gameNameKey] ?? 0.0) +
              purchase.price;

          if (!hasPlaytime) {
            final key = (year: year, gameNameKey: gameNameKey);
            untrackedDlcSpendingByYearAndGameName[key] =
                (untrackedDlcSpendingByYearAndGameName[key] ?? 0.0) +
                purchase.price;
          }
      }

      if (!hasPlaytime) {
        continue;
      }

      aggregate.totalPlaytimeHours += purchase.playtimeHours!;
      aggregate.playtimeByYear[year] =
          (aggregate.playtimeByYear[year] ?? 0.0) + purchase.playtimeHours!;
      aggregate.totalSpentWithPlaytime += purchase.price;
      aggregate.spendingWithPlaytimeByYear[year] =
          (aggregate.spendingWithPlaytimeByYear[year] ?? 0.0) + purchase.price;
    }

    for (final entry in untrackedDlcSpendingByYearAndGameName.entries) {
      if (!aggregate.gameNamesWithTrackedPlaytime.contains(
        entry.key.gameNameKey,
      )) {
        continue;
      }

      aggregate.totalSpentWithPlaytime += entry.value;
      aggregate.spendingWithPlaytimeByYear[entry.key.year] =
          (aggregate.spendingWithPlaytimeByYear[entry.key.year] ?? 0.0) +
          entry.value;
    }

    return aggregate;
  }

  Map<int, double?> _buildPricePerHourByYear() {
    final result = <int, double?>{};

    for (final year in years) {
      result[year] = _pricePerHour(
        _spendingWithPlaytimeByYear[year] ?? 0.0,
        _playtimeByYear[year] ?? 0.0,
      );
    }

    return result;
  }

  _QuarterAggregate _quarterAggregateForYear(int year) {
    return _quarterAggregatesByYear.putIfAbsent(
      year,
      () => _buildQuarterAggregateForYear(year),
    );
  }

  _QuarterAggregate _buildQuarterAggregateForYear(int year) {
    final aggregate = _QuarterAggregate();

    for (final purchase in purchases) {
      if (purchase.year != year) {
        continue;
      }

      final quarter = purchase.quarter;
      aggregate.spending[quarter] += purchase.price;
      aggregate.actualSpending += purchase.price;

      aggregate.discounts[quarter].add(purchase);
      aggregate.totalDiscount.add(purchase);

      if (_hasPlaytime(purchase)) {
        aggregate.playtime[quarter] += purchase.playtimeHours!;
        aggregate.totalPlaytime += purchase.playtimeHours!;
      }

      if (_countsTowardsPricePerHourSpending(purchase)) {
        aggregate.trackedSpending[quarter] += purchase.price;
        aggregate.totalTrackedSpending += purchase.price;
      }
    }

    return aggregate;
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

  double? _pricePerHour(double spending, double playtimeHours) {
    if (playtimeHours <= 0) {
      return null;
    }

    return spending / playtimeHours;
  }

  bool _hasPlaytime(SteamPurchase purchase) {
    final playtimeHours = purchase.playtimeHours;

    return playtimeHours != null && playtimeHours > 0;
  }

  bool _countsTowardsPricePerHourSpending(SteamPurchase purchase) {
    if (_hasPlaytime(purchase)) {
      return true;
    }

    if (purchase.purchaseType != SteamPurchaseType.dlc) {
      return false;
    }

    return _gameNamesWithTrackedPlaytime.contains(
      _gameNameKey(purchase.gameName),
    );
  }

  String _gameNameKey(String gameName) {
    return gameName.trim().toLowerCase();
  }
}

class _StatisticsAggregate {
  final Set<String> gameNamesWithTrackedPlaytime = {};
  final Map<String, double> dlcSpendingByGameName = {};
  final Map<int, double> spendingByYear = {};
  final Map<int, double> playtimeByYear = {};
  final Map<int, double> spendingWithPlaytimeByYear = {};
  final Map<int, _DiscountAggregate> discountsByYear = {};
  final _DiscountAggregate totalDiscount = _DiscountAggregate();

  int totalGames = 0;
  int totalDlcs = 0;
  int? firstYear;
  int? lastYear;
  double totalSpent = 0.0;
  double totalOriginalPrice = 0.0;
  double totalPlaytimeHours = 0.0;
  double totalSpentWithPlaytime = 0.0;

  double? get averageDiscount => totalDiscount.averageDiscount;

  void addYear(int year) {
    final currentFirstYear = firstYear;
    final currentLastYear = lastYear;

    if (currentFirstYear == null || year < currentFirstYear) {
      firstYear = year;
    }

    if (currentLastYear == null || year > currentLastYear) {
      lastYear = year;
    }
  }

  Map<int, double?> averageDiscountByYear(Iterable<int> years) {
    return {
      for (final year in years) year: discountsByYear[year]?.averageDiscount,
    };
  }
}

class _QuarterAggregate {
  final List<double> spending = List.filled(5, 0.0);
  final List<double> playtime = List.filled(5, 0.0);
  final List<double> trackedSpending = List.filled(5, 0.0);
  final List<_DiscountAggregate> discounts = List.generate(
    5,
    (_) => _DiscountAggregate(),
  );

  double actualSpending = 0.0;
  double totalPlaytime = 0.0;
  double totalTrackedSpending = 0.0;
  final _DiscountAggregate totalDiscount = _DiscountAggregate();

  double? get averageDiscount => totalDiscount.averageDiscount;

  double? averageDiscountForQuarter(int quarter) {
    return discounts[quarter].averageDiscount;
  }

  double? pricePerHourForQuarter(int quarter) {
    final hours = playtime[quarter];

    if (hours <= 0) {
      return null;
    }

    return trackedSpending[quarter] / hours;
  }
}

class _DiscountAggregate {
  double paidPrice = 0.0;
  double originalPrice = 0.0;

  void add(SteamPurchase purchase) {
    final purchaseOriginalPrice = purchase.originalPrice;

    if (purchaseOriginalPrice == null || purchaseOriginalPrice <= 0) {
      return;
    }

    paidPrice += purchase.price;
    originalPrice += purchaseOriginalPrice;
  }

  double? get averageDiscount {
    if (originalPrice <= 0) {
      return null;
    }

    return 1 - (paidPrice / originalPrice);
  }
}
