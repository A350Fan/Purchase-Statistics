import 'dart:math' as math;

import '../models/steam_purchase.dart';
import 'steam_statistics.dart';

enum SteamInsightReason {
  missingStatus,
  noPlaytime,
  barelyStarted,
  open,
  active,
  expensive,
  old,
  highCostPerHour,
  wellPlayed,
}

class SteamPurchaseInsight {
  final SteamPurchase purchase;
  final double totalPrice;
  final double? playtimeHours;
  final double? pricePerHour;
  final double score;
  final List<SteamInsightReason> reasons;

  const SteamPurchaseInsight({
    required this.purchase,
    required this.totalPrice,
    required this.playtimeHours,
    required this.pricePerHour,
    required this.score,
    required this.reasons,
  });
}

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

  double? playtimeForPurchase(SteamPurchase purchase) {
    final directPlaytime = purchase.playtimeHours;
    final inheritedPlaytime =
        _playtimeByGameName[_gameNameKey(purchase.gameName)];

    if (directPlaytime != null && directPlaytime > 0) {
      return math.max(directPlaytime, inheritedPlaytime ?? 0);
    }

    return inheritedPlaytime;
  }

  List<SteamPurchaseInsight> _buildBacklogPriority() {
    final insights =
        backlogGames
            .where((purchase) {
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
    final insights = startedBacklogGames.map(_insightForPurchase).toList()
      ..sort((a, b) {
        final activeCompare = _activeRank(
          b.purchase,
        ).compareTo(_activeRank(a.purchase));

        if (activeCompare != 0) {
          return activeCompare;
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

      return playtimeHours > 0 && playtimeHours < wellPlayedStatusReviewLimit;
    }).toList();

    purchases.sort((a, b) {
      final activeCompare = _activeRank(b).compareTo(_activeRank(a));

      if (activeCompare != 0) {
        return activeCompare;
      }

      return (playtimeForPurchase(b) ?? 0).compareTo(
        playtimeForPurchase(a) ?? 0,
      );
    });

    return purchases;
  }

  List<SteamPurchase> _buildStatusReviewGames() {
    final purchases = gamePurchases.where((purchase) {
      return purchase.gameStatus == null &&
          (playtimeForPurchase(purchase) ?? 0) >= wellPlayedStatusReviewLimit;
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
      pricePerHour: pricePerHourForPurchase(purchase),
      score: 0,
      reasons: _reasonsForPurchase(purchase),
    );
  }

  double _backlogScore(SteamPurchase purchase) {
    final totalPrice = priceIncludingLinkedDlcsForPurchase(purchase);
    final playtimeHours = playtimeForPurchase(purchase) ?? 0;
    final ageDays = currentDate
        .difference(_dateOnly(purchase.purchaseDate))
        .inDays;
    final costScore = _clamp01(totalPrice / 80) * 35;
    final ageScore = _clamp01(ageDays / (365 * 4)) * 25;
    final statusScore = switch (purchase.gameStatus) {
      SteamGameStatus.active => 18.0,
      SteamGameStatus.open => 15.0,
      null => 12.0,
      _ => 0.0,
    };
    final playtimeScore = switch (playtimeHours) {
      <= 0 => 25.0,
      < 5 => 16.0,
      < nextUpPlaytimeLimit => 8.0,
      _ => 0.0,
    };
    final playtimePenalty = _clamp01(playtimeHours / 80) * 35;

    return math.max(
      0,
      costScore + ageScore + statusScore + playtimeScore - playtimePenalty,
    );
  }

  List<SteamInsightReason> _reasonsForPurchase(SteamPurchase purchase) {
    final reasons = <SteamInsightReason>[];
    final playtimeHours = playtimeForPurchase(purchase) ?? 0;
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
      case null:
        reasons.add(SteamInsightReason.missingStatus);
        break;
      case SteamGameStatus.completed:
      case SteamGameStatus.endless:
      case SteamGameStatus.abandoned:
      case SteamGameStatus.archived:
        break;
    }

    if (playtimeHours <= 0) {
      reasons.add(SteamInsightReason.noPlaytime);
    } else if (playtimeHours < 5) {
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
      SteamGameStatus.open || SteamGameStatus.active => true,
      null =>
        (playtimeForPurchase(purchase) ?? 0) < wellPlayedStatusReviewLimit,
    };
  }

  bool _hasPlaytime(SteamPurchase purchase) {
    final playtimeHours = playtimeForPurchase(purchase);

    return playtimeHours != null && playtimeHours > 0;
  }

  int _activeRank(SteamPurchase purchase) {
    return purchase.gameStatus == SteamGameStatus.active ? 1 : 0;
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
      result[gameNameKey] = math.max(result[gameNameKey] ?? 0, playtimeHours);
    }

    return result;
  }

  String _gameNameKey(String gameName) {
    return gameName.trim().toLowerCase();
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
