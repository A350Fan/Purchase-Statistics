// SPDX-License-Identifier: GPL-3.0-or-later
/// Persistente Zielwerte fuer den Ziele-Tab.
///
/// Alle Felder sind optional: `null` bedeutet, dass das jeweilige Ziel nicht
/// gesetzt ist und in der UI als deaktiviert behandelt wird.
class SteamGoalSettings {
  final double? annualSpendingLimit;
  final int? backlogLimit;
  final int? unplayedBacklogLimit;
  final double? unplayedBacklogValueLimit;
  final double? completionRateTarget;

  const SteamGoalSettings({
    this.annualSpendingLimit,
    this.backlogLimit,
    this.unplayedBacklogLimit,
    this.unplayedBacklogValueLimit,
    this.completionRateTarget,
  });

  /// Schnellpruefung, ob ueberhaupt ein Ziel aktiv ist.
  bool get hasAnyGoal {
    return annualSpendingLimit != null ||
        backlogLimit != null ||
        unplayedBacklogLimit != null ||
        unplayedBacklogValueLimit != null ||
        completionRateTarget != null;
  }

  /// Serialisiert die Ziele in die Einzelzeile der Tabelle `steam_goals`.
  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'annual_spending_limit': annualSpendingLimit,
      'backlog_limit': backlogLimit,
      'unplayed_backlog_limit': unplayedBacklogLimit,
      'unplayed_backlog_value_limit': unplayedBacklogValueLimit,
      'completion_rate_target': completionRateTarget,
    };
  }

  /// Baut Ziele aus einer Datenbankzeile.
  factory SteamGoalSettings.fromMap(Map<String, Object?> map) {
    return SteamGoalSettings(
      annualSpendingLimit: _nullableDouble(map['annual_spending_limit']),
      backlogLimit: _nullableInt(map['backlog_limit']),
      unplayedBacklogLimit: _nullableInt(map['unplayed_backlog_limit']),
      unplayedBacklogValueLimit: _nullableDouble(
        map['unplayed_backlog_value_limit'],
      ),
      completionRateTarget: _nullableDouble(map['completion_rate_target']),
    );
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) {
      return null;
    }

    return (value as num).toDouble();
  }

  static int? _nullableInt(Object? value) {
    if (value == null) {
      return null;
    }

    return (value as num).toInt();
  }
}
