import '../models/steam_goal_settings.dart';
import '../models/steam_purchase.dart';
import 'steam_insights.dart';
import 'steam_statistics.dart';

/// Gibt an, ob ein Ziel einen Hoechstwert oder einen Mindestwert beschreibt.
enum SteamGoalDirection { maximum, minimum }

/// Bewertungszustand eines Ziels fuer die UI.
enum SteamGoalState { unset, onTrack, atRisk, offTrack }

/// Ergebnis einer einzelnen Zielpruefung.
///
/// `actualValue` ist der aktuelle Stand. `projectedValue` ist optional und wird
/// z.B. fuer Jahresausgaben verwendet, um eine Hochrechnung zu bewerten.
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

  /// Wert, der fuer die Ampelentscheidung genutzt wird: Projektion vor Istwert,
  /// falls vorhanden.
  double get comparisonValue => projectedValue ?? actualValue;

  /// Fortschritt relativ zum Ziel.
  ///
  /// Der Wert kann groesser als 1 sein, wenn ein Ziel ueber- bzw.
  /// unterschritten wurde; die UI kann ihn bei Bedarf begrenzen.
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

    // Wenn die Projektion passt, ist das Ziel auf Kurs. Wenn nur der aktuelle
    // Wert passt, die Projektion aber nicht, ist das Ziel gefaehrdet.
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

/// Aggregiert alle Zielwerte, die der Ziele-Tab anzeigt.
///
/// Die Klasse kombiniert Statistik- und Insight-Berechnungen, damit die UI nur
/// noch fertige `SteamGoalResult`s rendern muss.
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
    // Jahresausgaben werden direkt aus der Kauf-Liste summiert, damit auch ein
    // ausgewaehltes vergangenes Jahr unabhaengig vom aktuellen Datum funktioniert.
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
