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

  late final Set<String> _gameNamesWithTrackedPlaytime =
      _buildGameNamesWithTrackedPlaytime();
  late final Map<String, double> _dlcSpendingByGameName =
      _buildDlcSpendingByGameName();
  late final Map<int, double> _spendingByYear = _buildSpendingByYear();
  late final Map<int, double> _playtimeByYear = _buildPlaytimeByYear();
  late final Map<int, double> _spendingWithPlaytimeByYear =
      _buildSpendingWithPlaytimeByYear();
  late final Map<int, double?> _averageDiscountByYear =
      _buildAverageDiscountByYear();
  late final Map<int, double?> _pricePerHourByYear = _buildPricePerHourByYear();

  late final double totalSpent = _sumSpent();
  late final int totalGames = _countPurchaseType(SteamPurchaseType.game);
  late final int totalDlcs = _countPurchaseType(SteamPurchaseType.dlc);
  late final double totalOriginalPrice = _sumOriginalPrice();
  late final double totalPlaytimeHours = _sumPlaytime();
  late final double totalSpentWithPlaytime = _sumSpentWithPlaytime();
  late final double? pricePerHour = _pricePerHour(
    totalSpentWithPlaytime,
    totalPlaytimeHours,
  );
  late final double? averageDiscount = _averageDiscountFor(purchases);
  late final List<int> years = _buildYears();
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
    if (purchases.isEmpty) {
      return const [];
    }

    var firstYear = purchases.first.year;
    var lastYear = purchases.first.year;

    for (var index = 1; index < purchases.length; index++) {
      final purchase = purchases[index];

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

    return List.unmodifiable([
      for (var year = firstYear; year <= lastYear; year++) year,
    ]);
  }

  Map<int, double> _buildSpendingByYear() {
    final result = <int, double>{};

    for (final purchase in purchases) {
      result[purchase.year] = (result[purchase.year] ?? 0.0) + purchase.price;
    }

    return result;
  }

  Map<int, double> _buildPlaytimeByYear() {
    final result = <int, double>{};

    for (final purchase in purchases) {
      if (!_hasPlaytime(purchase)) {
        continue;
      }

      result[purchase.year] =
          (result[purchase.year] ?? 0.0) + purchase.playtimeHours!;
    }

    return result;
  }

  Map<int, double> _buildSpendingWithPlaytimeByYear() {
    final result = <int, double>{};

    for (final purchase in purchases) {
      if (!_countsTowardsPricePerHourSpending(purchase)) {
        continue;
      }

      result[purchase.year] = (result[purchase.year] ?? 0.0) + purchase.price;
    }

    return result;
  }

  Map<int, double?> _buildAverageDiscountByYear() {
    final discountsByYear = <int, _DiscountAggregate>{};

    for (final purchase in purchases) {
      discountsByYear
          .putIfAbsent(purchase.year, () => _DiscountAggregate())
          .add(purchase);
    }

    final result = <int, double?>{};

    for (final year in years) {
      result[year] = discountsByYear[year]?.averageDiscount;
    }

    return result;
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

  double _sumSpent() {
    var sum = 0.0;

    for (final purchase in purchases) {
      sum += purchase.price;
    }

    return sum;
  }

  int _countPurchaseType(SteamPurchaseType type) {
    var count = 0;

    for (final purchase in purchases) {
      if (purchase.purchaseType == type) {
        count++;
      }
    }

    return count;
  }

  double _sumOriginalPrice() {
    var sum = 0.0;

    for (final purchase in purchases) {
      sum += purchase.originalPrice ?? purchase.price;
    }

    return sum;
  }

  double _sumPlaytime() {
    var sum = 0.0;

    for (final purchase in purchases) {
      if (_hasPlaytime(purchase)) {
        sum += purchase.playtimeHours!;
      }
    }

    return sum;
  }

  double _sumSpentWithPlaytime() {
    var sum = 0.0;

    for (final purchase in purchases) {
      if (_countsTowardsPricePerHourSpending(purchase)) {
        sum += purchase.price;
      }
    }

    return sum;
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

  double? _averageDiscountFor(Iterable<SteamPurchase> purchases) {
    final discount = _DiscountAggregate();

    for (final purchase in purchases) {
      discount.add(purchase);
    }

    return discount.averageDiscount;
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

  Set<String> _buildGameNamesWithTrackedPlaytime() {
    final result = <String>{};

    for (final purchase in purchases) {
      if (purchase.purchaseType == SteamPurchaseType.game &&
          _hasPlaytime(purchase)) {
        result.add(_gameNameKey(purchase.gameName));
      }
    }

    return result;
  }

  Map<String, double> _buildDlcSpendingByGameName() {
    final result = <String, double>{};

    for (final purchase in purchases) {
      if (purchase.purchaseType != SteamPurchaseType.dlc) {
        continue;
      }

      final gameNameKey = _gameNameKey(purchase.gameName);
      result[gameNameKey] = (result[gameNameKey] ?? 0.0) + purchase.price;
    }

    return result;
  }

  String _gameNameKey(String gameName) {
    return gameName.trim().toLowerCase();
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
