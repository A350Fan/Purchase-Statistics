// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import '../models/steam_purchase.dart';
import 'steam_statistics.dart';

/// Gruende, die erklaeren, warum ein Kauf in einer Insight-Liste auftaucht.
enum SteamInsightReason {
  missingStatus,
  noPlaytime,
  barelyStarted,
  open,
  active,
  paused,
  expensive,
  old,
  highCostPerHour,
  wellPlayed,
  shortGame,
  nearlyFinished,
}

/// Aufbereitete Empfehlung/Einordnung fuer einen einzelnen Kauf.
class SteamPurchaseInsight {
  final SteamPurchase purchase;
  final double totalPrice;
  final double? playtimeHours;
  final double? estimatedLengthHours;
  final double? estimatedProgress;
  final double? pricePerHour;
  final double score;
  final List<SteamInsightReason> reasons;

  const SteamPurchaseInsight({
    required this.purchase,
    required this.totalPrice,
    required this.playtimeHours,
    required this.estimatedLengthHours,
    required this.estimatedProgress,
    required this.pricePerHour,
    required this.score,
    required this.reasons,
  });
}

/// Berechnet Backlog-, Status- und Kosten-Insights aus den Kaeufen.
///
/// Anders als `SteamStatistics` geht es hier weniger um reine Summen und mehr
/// um priorisierte Listen: Was ist ungespielt teuer, was sollte als Naechstes
/// gespielt werden, welche Status fehlen?
class SteamInsights {
  static const double nextUpPlaytimeLimit = 20;
  static const double wellPlayedStatusReviewLimit = 40;
  static const double highCostPerHourLimit = 3;

  final List<SteamPurchase> purchases;
  final DateTime currentDate;

  late final SteamStatistics _statistics = SteamStatistics(
    purchases,
    currentDate: currentDate,
  );
  late final Map<String, double> _playtimeByGameName =
      _buildPlaytimeByGameName();
  late final Map<String, double> _lengthEstimateByGameName =
      _buildLengthEstimateByGameName();

  late final List<SteamPurchase> gamePurchases = List.unmodifiable(
    purchases.where((purchase) {
      return purchase.purchaseType == SteamPurchaseType.game;
    }),
  );
  late final List<SteamPurchase> backlogGames = List.unmodifiable(
    gamePurchases.where(_isBacklogGame),
  );
  late final List<SteamPurchase> unplayedBacklogGames = List.unmodifiable(
    backlogGames.where((purchase) => !_hasPlaytime(purchase)),
  );
  late final List<SteamPurchase> startedBacklogGames = List.unmodifiable(
    _sortedStartedBacklogGames(),
  );
  late final List<SteamPurchase> completedGames = List.unmodifiable(
    gamePurchases.where((purchase) {
      return purchase.gameStatus == SteamGameStatus.completed;
    }),
  );
  late final List<SteamPurchase> abandonedGames = List.unmodifiable(
    gamePurchases.where((purchase) {
      return purchase.gameStatus == SteamGameStatus.abandoned;
    }),
  );
  late final List<SteamPurchase> trackableGames = List.unmodifiable(
    gamePurchases.where((purchase) {
      return purchase.gameStatus != null &&
          purchase.gameStatus != SteamGameStatus.endless &&
          purchase.gameStatus != SteamGameStatus.archived;
    }),
  );
  late final List<SteamPurchase> statusReviewGames = List.unmodifiable(
    _buildStatusReviewGames(),
  );

  late final double backlogValue = _sumTotalPrices(backlogGames);
  late final double unplayedBacklogValue = _sumTotalPrices(
    unplayedBacklogGames,
  );
  late final double abandonedValue = _sumTotalPrices(abandonedGames);
  late final double? completionRate = trackableGames.isEmpty
      ? null
      : completedGames.length / trackableGames.length;

  late final List<SteamPurchaseInsight> backlogPriority =
      _buildBacklogPriority();
  late final List<SteamPurchaseInsight> expensiveUnplayedGames =
      _buildExpensiveUnplayedGames();
  late final List<SteamPurchaseInsight> startedBacklog = _buildStartedBacklog();
  late final List<SteamPurchaseInsight> highCostPerHourGames =
      _buildHighCostPerHourGames();
  late final List<SteamPurchaseInsight> abandonedSpend = _buildAbandonedSpend();

  SteamInsights(this.purchases, {DateTime? currentDate})
    : currentDate = _dateOnly(currentDate ?? DateTime.now());

  /// Preis eines Spiels inklusive verknuepfter DLCs.
  double priceIncludingLinkedDlcsForPurchase(SteamPurchase purchase) {
    return _statistics.priceIncludingLinkedDlcsForPurchase(purchase);
  }

  double? pricePerHourForPurchase(SteamPurchase purchase) {
    final playtimeHours = playtimeForPurchase(purchase);

    if (playtimeHours == null || playtimeHours <= 0) {
      return null;
    }

    return priceIncludingLinkedDlcsForPurchase(purchase) / playtimeHours;
  }

  /// Spielzeit eines Kaufs.
  ///
  /// Bei DLCs oder doppelten Spielnamen kann Spielzeit vom Basisspiel geerbt
  /// werden. Der groesste bekannte Wert gewinnt.
  double? playtimeForPurchase(SteamPurchase purchase) {
    final directPlaytime = purchase.playtimeHours;
    final inheritedPlaytime =
        _playtimeByGameName[_gameNameKey(purchase.gameName)];

    if (directPlaytime != null && directPlaytime > 0) {
      return math.max(directPlaytime, inheritedPlaytime ?? 0);
    }

    return inheritedPlaytime;
  }

  /// Laengenschaetzung aus direkter Angabe oder einem anderen Kauf desselben
  /// Spiels.
  double? estimatedLengthForPurchase(SteamPurchase purchase) {
    return _directLengthEstimateForPurchase(purchase) ??
        _lengthEstimateByGameName[_gameNameKey(purchase.gameName)];
  }

  /// Geschaetzter Fortschritt als Spielzeit geteilt durch erwartete Laenge.
  double? estimatedProgressForPurchase(SteamPurchase purchase) {
    final playtimeHours = playtimeForPurchase(purchase);
    final estimatedLengthHours = estimatedLengthForPurchase(purchase);

    if (playtimeHours == null ||
        playtimeHours <= 0 ||
        estimatedLengthHours == null ||
        estimatedLengthHours <= 0) {
      return null;
    }

    return playtimeHours / estimatedLengthHours;
  }

  List<SteamPurchaseInsight> _buildBacklogPriority() {
    // Priorisiert offene, aktive und pausierte Backlog-Spiele, die noch nicht
    // fertig wirken oder wenig Spielzeit haben.
    final insights =
        backlogGames
            .where((purchase) {
              if (_isBacklogPrioritySnoozed(purchase)) {
                return false;
              }

              final estimatedProgress = estimatedProgressForPurchase(purchase);

              if (estimatedProgress != null) {
                return estimatedProgress < 1;
              }

              return (playtimeForPurchase(purchase) ?? 0) < nextUpPlaytimeLimit;
            })
            .map(_insightForBacklogPurchase)
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);

            if (scoreCompare != 0) {
              return scoreCompare;
            }

            return _comparePurchaseAge(a.purchase, b.purchase);
          });

    return List.unmodifiable(insights);
  }

  List<SteamPurchaseInsight> _buildExpensiveUnplayedGames() {
    // Teure ungespielte Backlog-Titel zuerst, bei gleichem Preis aeltere zuerst.
    final insights = unplayedBacklogGames.map(_insightForPurchase).toList()
      ..sort((a, b) {
        final priceCompare = b.totalPrice.compareTo(a.totalPrice);

        if (priceCompare != 0) {
          return priceCompare;
        }

        return _comparePurchaseAge(a.purchase, b.purchase);
      });

    return List.unmodifiable(insights);
  }

  List<SteamPurchaseInsight> _buildStartedBacklog() {
    // Begonnene Backlog-Spiele werden so sortiert, dass aktive, pausierte und
    // bereits investierte Titel sichtbar nach oben kommen.
    final insights = startedBacklogGames.map(_insightForPurchase).toList()
      ..sort((a, b) {
        final resumeCompare = _resumeRank(
          b.purchase,
        ).compareTo(_resumeRank(a.purchase));

        if (resumeCompare != 0) {
          return resumeCompare;
        }

        final playtimeCompare = (b.playtimeHours ?? 0).compareTo(
          a.playtimeHours ?? 0,
        );

        if (playtimeCompare != 0) {
          return playtimeCompare;
        }

        return _comparePurchaseAge(a.purchase, b.purchase);
      });

    return List.unmodifiable(insights);
  }

  List<SteamPurchaseInsight> _buildHighCostPerHourGames() {
    final insights =
        backlogGames
            .where((purchase) {
              final pricePerHour = pricePerHourForPurchase(purchase);

              return pricePerHour != null &&
                  pricePerHour >= highCostPerHourLimit;
            })
            .map(_insightForPurchase)
            .toList()
          ..sort((a, b) {
            final costCompare = (b.pricePerHour ?? 0).compareTo(
              a.pricePerHour ?? 0,
            );

            if (costCompare != 0) {
              return costCompare;
            }

            return b.totalPrice.compareTo(a.totalPrice);
          });

    return List.unmodifiable(insights);
  }

  List<SteamPurchaseInsight> _buildAbandonedSpend() {
    final insights = abandonedGames.map(_insightForPurchase).toList()
      ..sort((a, b) {
        final priceCompare = b.totalPrice.compareTo(a.totalPrice);

        if (priceCompare != 0) {
          return priceCompare;
        }

        return _comparePurchaseAge(a.purchase, b.purchase);
      });

    return List.unmodifiable(insights);
  }

  List<SteamPurchase> _sortedStartedBacklogGames() {
    final purchases = backlogGames.where((purchase) {
      final playtimeHours = playtimeForPurchase(purchase) ?? 0;
      final estimatedProgress = estimatedProgressForPurchase(purchase);

      if (playtimeHours <= 0) {
        return false;
      }

      if (estimatedProgress != null) {
        return estimatedProgress < 1;
      }

      return playtimeHours < wellPlayedStatusReviewLimit;
    }).toList();

    purchases.sort((a, b) {
      final resumeCompare = _resumeRank(b).compareTo(_resumeRank(a));

      if (resumeCompare != 0) {
        return resumeCompare;
      }

      return (playtimeForPurchase(b) ?? 0).compareTo(
        playtimeForPurchase(a) ?? 0,
      );
    });

    return purchases;
  }

  List<SteamPurchase> _buildStatusReviewGames() {
    final purchases = gamePurchases.where((purchase) {
      final estimatedProgress = estimatedProgressForPurchase(purchase);

      return purchase.gameStatus == null &&
          ((playtimeForPurchase(purchase) ?? 0) >=
                  wellPlayedStatusReviewLimit ||
              (estimatedProgress != null && estimatedProgress >= 1));
    }).toList();

    purchases.sort((a, b) {
      return (playtimeForPurchase(b) ?? 0).compareTo(
        playtimeForPurchase(a) ?? 0,
      );
    });

    return purchases;
  }

  SteamPurchaseInsight _insightForBacklogPurchase(SteamPurchase purchase) {
    return SteamPurchaseInsight(
      purchase: purchase,
      totalPrice: priceIncludingLinkedDlcsForPurchase(purchase),
      playtimeHours: playtimeForPurchase(purchase),
      estimatedLengthHours: estimatedLengthForPurchase(purchase),
      estimatedProgress: estimatedProgressForPurchase(purchase),
      pricePerHour: pricePerHourForPurchase(purchase),
      score: _backlogScore(purchase),
      reasons: _reasonsForPurchase(purchase),
    );
  }

  SteamPurchaseInsight _insightForPurchase(SteamPurchase purchase) {
    return SteamPurchaseInsight(
      purchase: purchase,
      totalPrice: priceIncludingLinkedDlcsForPurchase(purchase),
      playtimeHours: playtimeForPurchase(purchase),
      estimatedLengthHours: estimatedLengthForPurchase(purchase),
      estimatedProgress: estimatedProgressForPurchase(purchase),
      pricePerHour: pricePerHourForPurchase(purchase),
      score: 0,
      reasons: _reasonsForPurchase(purchase),
    );
  }

  double _backlogScore(SteamPurchase purchase) {
    final totalPrice = priceIncludingLinkedDlcsForPurchase(purchase);
    final playtimeHours = playtimeForPurchase(purchase) ?? 0;
    final estimatedLength = estimatedLengthForPurchase(purchase);
    final estimatedProgress = estimatedProgressForPurchase(purchase);
    final ageDays = currentDate
        .difference(_dateOnly(purchase.purchaseDate))
        .inDays;
    final costScore = _clamp01(totalPrice / 80) * 35;
    final ageScore = _clamp01(ageDays / (365 * 4)) * 25;
    final statusScore = switch (purchase.gameStatus) {
      SteamGameStatus.active => 18.0,
      SteamGameStatus.paused => 16.0,
      SteamGameStatus.open => 15.0,
      null => 12.0,
      _ => 0.0,
    };
    final playtimeScore = estimatedProgress == null
        ? switch (playtimeHours) {
            <= 0 => 25.0,
            < 5 => 16.0,
            < nextUpPlaytimeLimit => 8.0,
            _ => 0.0,
          }
        : switch (estimatedProgress) {
            >= 0.75 && < 1 => 24.0,
            < 0.2 => 12.0,
            < 0.75 => 16.0,
            _ => 0.0,
          };
    final lengthScore = estimatedLength == null
        ? 0.0
        : switch (estimatedLength) {
            <= 8 => 18.0,
            <= 15 => 10.0,
            _ => 0.0,
          };
    final playtimePenalty = estimatedProgress == null
        ? _clamp01(playtimeHours / 80) * 35
        : 0.0;

    // Score-Heuristik: teuer, alt, offen/aktiv und kurz/fast fertig erhoehen die
    // Prioritaet; sehr viel Spielzeit ohne Laengenschaetzung senkt sie.
    return math.max(
      0,
      costScore +
          ageScore +
          statusScore +
          playtimeScore +
          lengthScore -
          playtimePenalty,
    );
  }

  List<SteamInsightReason> _reasonsForPurchase(SteamPurchase purchase) {
    // Die Gruende sind bewusst getrennt vom Score, damit die UI erklaeren kann,
    // warum ein Spiel vorgeschlagen wird.
    final reasons = <SteamInsightReason>[];
    final playtimeHours = playtimeForPurchase(purchase) ?? 0;
    final estimatedLength = estimatedLengthForPurchase(purchase);
    final estimatedProgress = estimatedProgressForPurchase(purchase);
    final pricePerHour = pricePerHourForPurchase(purchase);
    final ageDays = currentDate
        .difference(_dateOnly(purchase.purchaseDate))
        .inDays;

    switch (purchase.gameStatus) {
      case SteamGameStatus.open:
        reasons.add(SteamInsightReason.open);
        break;
      case SteamGameStatus.active:
        reasons.add(SteamInsightReason.active);
        break;
      case SteamGameStatus.paused:
        reasons.add(SteamInsightReason.paused);
        break;
      case null:
        reasons.add(SteamInsightReason.missingStatus);
        break;
      case SteamGameStatus.completed:
      case SteamGameStatus.endless:
      case SteamGameStatus.abandoned:
      case SteamGameStatus.archived:
        break;
    }

    if (estimatedLength != null && estimatedLength <= 10) {
      reasons.add(SteamInsightReason.shortGame);
    }

    if (estimatedProgress != null &&
        estimatedProgress >= 0.75 &&
        estimatedProgress < 1) {
      reasons.add(SteamInsightReason.nearlyFinished);
    }

    if (playtimeHours <= 0) {
      reasons.add(SteamInsightReason.noPlaytime);
    } else if (estimatedProgress == null && playtimeHours < 5 ||
        estimatedProgress != null && estimatedProgress < 0.2) {
      reasons.add(SteamInsightReason.barelyStarted);
    } else if (playtimeHours >= wellPlayedStatusReviewLimit) {
      reasons.add(SteamInsightReason.wellPlayed);
    }

    if (priceIncludingLinkedDlcsForPurchase(purchase) >= 50) {
      reasons.add(SteamInsightReason.expensive);
    }

    if (ageDays >= 365 * 2) {
      reasons.add(SteamInsightReason.old);
    }

    if (pricePerHour != null && pricePerHour >= highCostPerHourLimit) {
      reasons.add(SteamInsightReason.highCostPerHour);
    }

    return List.unmodifiable(reasons);
  }

  double _sumTotalPrices(Iterable<SteamPurchase> purchases) {
    var sum = 0.0;

    for (final purchase in purchases) {
      sum += priceIncludingLinkedDlcsForPurchase(purchase);
    }

    return sum;
  }

  bool _isBacklogGame(SteamPurchase purchase) {
    return switch (purchase.gameStatus) {
      SteamGameStatus.completed ||
      SteamGameStatus.endless ||
      SteamGameStatus.abandoned ||
      SteamGameStatus.archived => false,
      SteamGameStatus.open ||
      SteamGameStatus.active ||
      SteamGameStatus.paused => true,
      null => !_shouldReviewStatus(purchase),
    };
  }

  bool _isBacklogPrioritySnoozed(SteamPurchase purchase) {
    final snoozedUntil = purchase.backlogPrioritySnoozedUntil;

    if (snoozedUntil == null) {
      return false;
    }

    // Der Snooze betrifft nur die Empfehlungsliste. Am gespeicherten Datum
    // selbst darf das Spiel wieder als Vorschlag auftauchen.
    return currentDate.isBefore(_dateOnly(snoozedUntil));
  }

  bool _hasPlaytime(SteamPurchase purchase) {
    final playtimeHours = playtimeForPurchase(purchase);

    return playtimeHours != null && playtimeHours > 0;
  }

  int _resumeRank(SteamPurchase purchase) {
    // Aktive Spiele stehen vor pausierten; pausierte bleiben aber sichtbare
    // Wiedereinstiegs-Kandidaten vor neutral offenen Titeln.
    return switch (purchase.gameStatus) {
      SteamGameStatus.active => 2,
      SteamGameStatus.paused => 1,
      _ => 0,
    };
  }

  int _comparePurchaseAge(SteamPurchase a, SteamPurchase b) {
    return a.purchaseDate.compareTo(b.purchaseDate);
  }

  double _clamp01(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  Map<String, double> _buildPlaytimeByGameName() {
    final result = <String, double>{};

    for (final purchase in purchases) {
      if (purchase.purchaseType != SteamPurchaseType.game) {
        continue;
      }

      final playtimeHours = purchase.playtimeHours;

      if (playtimeHours == null || playtimeHours <= 0) {
        continue;
      }

      final gameNameKey = _gameNameKey(purchase.gameName);
      // Bei mehrfachen Eintraegen desselben Spiels behalten wir die hoechste
      // bekannte Spielzeit.
      result[gameNameKey] = math.max(result[gameNameKey] ?? 0, playtimeHours);
    }

    return result;
  }

  Map<String, double> _buildLengthEstimateByGameName() {
    final result = <String, double>{};

    for (final purchase in purchases) {
      if (purchase.purchaseType != SteamPurchaseType.game) {
        continue;
      }

      final lengthEstimate = _directLengthEstimateForPurchase(purchase);

      if (lengthEstimate == null || lengthEstimate <= 0) {
        continue;
      }

      final gameNameKey = _gameNameKey(purchase.gameName);
      final currentEstimate = result[gameNameKey];
      // Fuer Backlog-Prioritaet ist die kuerzeste plausible Laenge hilfreicher:
      // ein Spiel kann dadurch als "schnell abschliessbar" erkannt werden.
      result[gameNameKey] = currentEstimate == null
          ? lengthEstimate
          : math.min(currentEstimate, lengthEstimate);
    }

    return result;
  }

  double? _directLengthEstimateForPurchase(SteamPurchase purchase) {
    if (purchase.purchaseType != SteamPurchaseType.game) {
      return null;
    }

    return purchase.mainStoryHours ??
        purchase.mainExtraHours ??
        purchase.completionistHours;
  }

  bool _shouldReviewStatus(SteamPurchase purchase) {
    final estimatedProgress = estimatedProgressForPurchase(purchase);

    return (playtimeForPurchase(purchase) ?? 0) >=
            wellPlayedStatusReviewLimit ||
        (estimatedProgress != null && estimatedProgress >= 1);
  }

  String _gameNameKey(String gameName) {
    return gameName.trim().toLowerCase();
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
