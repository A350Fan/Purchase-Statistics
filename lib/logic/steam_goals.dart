import '../models/steam_goal_settings.dart';
import '../models/steam_purchase.dart';
import 'steam_insights.dart';
import 'steam_statistics.dart';

enum SteamGoalDirection { maximum, minimum }

enum SteamGoalState { unset, onTrack, atRisk, offTrack }

class SteamGoalResult {
  final double actualValue;
  final double? projectedValue;
  final double? targetValue;
  final SteamGoalDirection direction;

  const SteamGoalResult({
    required this.actualValue,
    required this.targetValue,
    required this.direction,
    this.projectedValue,
  });

  bool get isSet => targetValue != null;

  double get comparisonValue => projectedValue ?? actualValue;

  double? get progress {
    final target = targetValue;

    if (target == null) {
      return null;
    }

    if (target <= 0) {
      return switch (direction) {
        SteamGoalDirection.maximum => actualValue <= 0 ? 0 : 1,
        SteamGoalDirection.minimum => 1,
      };
    }

    return actualValue / target;
  }

  SteamGoalState get state {
    final target = targetValue;

    if (target == null) {
      return SteamGoalState.unset;
    }

    final isActualMet = _meetsTarget(actualValue, target);
    final isComparisonMet = _meetsTarget(comparisonValue, target);

    if (isComparisonMet) {
      return SteamGoalState.onTrack;
    }

    if (isActualMet && projectedValue != null) {
      return SteamGoalState.atRisk;
    }

    return SteamGoalState.offTrack;
  }

  bool _meetsTarget(double value, double target) {
    return switch (direction) {
      SteamGoalDirection.maximum => value <= target,
      SteamGoalDirection.minimum => value >= target,
    };
  }
}

class SteamGoalsOverview {
  final List<SteamPurchase> purchases;
  final SteamGoalSettings settings;
  final int year;
  final DateTime currentDate;

  late final SteamStatistics _statistics = SteamStatistics(
    purchases,
    currentDate: currentDate,
  );
  late final SteamInsights _insights = SteamInsights(
    purchases,
    currentDate: currentDate,
  );

  late final double annualSpending = _spendingForYear(year);
  late final double? projectedAnnualSpending = year == currentDate.year
      ? _statistics.quarterlySummaryForYear(year).projectedSpending
      : null;
  late final int backlogCount = _insights.backlogGames.length;
  late final int unplayedBacklogCount = _insights.unplayedBacklogGames.length;
  late final double unplayedBacklogValue = _insights.unplayedBacklogValue;
  late final double? completionRate = _insights.completionRate;

  late final SteamGoalResult annualSpendingGoal = SteamGoalResult(
    actualValue: annualSpending,
    projectedValue: projectedAnnualSpending,
    targetValue: settings.annualSpendingLimit,
    direction: SteamGoalDirection.maximum,
  );
  late final SteamGoalResult backlogGoal = SteamGoalResult(
    actualValue: backlogCount.toDouble(),
    targetValue: settings.backlogLimit?.toDouble(),
    direction: SteamGoalDirection.maximum,
  );
  late final SteamGoalResult unplayedBacklogGoal = SteamGoalResult(
    actualValue: unplayedBacklogCount.toDouble(),
    targetValue: settings.unplayedBacklogLimit?.toDouble(),
    direction: SteamGoalDirection.maximum,
  );
  late final SteamGoalResult unplayedBacklogValueGoal = SteamGoalResult(
    actualValue: unplayedBacklogValue,
    targetValue: settings.unplayedBacklogValueLimit,
    direction: SteamGoalDirection.maximum,
  );
  late final SteamGoalResult completionRateGoal = SteamGoalResult(
    actualValue: completionRate ?? 0,
    targetValue: settings.completionRateTarget,
    direction: SteamGoalDirection.minimum,
  );

  SteamGoalsOverview({
    required this.purchases,
    required this.settings,
    required this.year,
    DateTime? currentDate,
  }) : currentDate = _dateOnly(currentDate ?? DateTime.now());

  double _spendingForYear(int year) {
    var spending = 0.0;

    for (final purchase in purchases) {
      if (purchase.year == year) {
        spending += purchase.price;
      }
    }

    return spending;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
