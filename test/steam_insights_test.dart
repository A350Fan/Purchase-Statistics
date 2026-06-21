// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/logic/steam_insights.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';

void main() {
  group('SteamInsights', () {
    test('summarizes backlog value and completion rate', () {
      final purchases = _buildInsightPurchases();
      final insights = SteamInsights(
        purchases,
        currentDate: DateTime(2026, 5, 24),
      );

      expect(insights.gamePurchases.length, 5);
      expect(insights.backlogGames.length, 2);
      expect(insights.unplayedBacklogGames.length, 1);
      expect(insights.completedGames.length, 1);
      expect(insights.abandonedGames.length, 1);
      expect(insights.backlogValue, 80);
      expect(insights.unplayedBacklogValue, 60);
      expect(insights.abandonedValue, 30);
      expect(insights.completionRate, 0.25);
    });

    test('builds sorted actionable insight lists', () {
      final purchases = _buildInsightPurchases();
      final insights = SteamInsights(
        purchases,
        currentDate: DateTime(2026, 5, 24),
      );

      expect(insights.backlogPriority.first.purchase.gameName, 'Big Backlog');
      expect(insights.backlogPriority.first.score, greaterThan(80));
      expect(insights.expensiveUnplayedGames.first.totalPrice, 60);
      expect(
        insights.startedBacklog.first.purchase.gameName,
        'Started Backlog',
      );
      expect(
        insights.highCostPerHourGames.first.purchase.gameName,
        'Started Backlog',
      );
      expect(insights.highCostPerHourGames.first.pricePerHour, 10);
      expect(insights.abandonedSpend.first.purchase.gameName, 'Dropped Game');
    });

    test('inherits playtime by game name for edition purchases', () {
      final insights = SteamInsights([
        SteamPurchase(
          purchaseDate: DateTime(2025, 11, 27),
          gameName: 'Euro Truck Simulator 2',
          edition: 'Ultimate',
          price: 92.88,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2021, 1, 1),
          gameName: 'Euro Truck Simulator 2',
          gameStatus: SteamGameStatus.completed,
          mainStoryHours: 60,
          price: 4.99,
          playtimeHours: 300,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 1, 1),
          gameName: 'Unplayed Game',
          price: 20,
        ),
      ], currentDate: DateTime(2026, 5, 24));

      final editionPurchase = insights.gamePurchases.first;

      expect(insights.playtimeForPurchase(editionPurchase), 300);
      expect(insights.backlogPriority.map((item) => item.purchase.gameName), [
        'Unplayed Game',
      ]);
      expect(
        insights.statusReviewGames.single.gameName,
        'Euro Truck Simulator 2',
      );
    });

    test('uses length estimates for progress and recommendation reasons', () {
      final insights = SteamInsights([
        SteamPurchase(
          purchaseDate: DateTime(2026, 1, 1),
          gameName: 'Almost Done',
          gameStatus: SteamGameStatus.active,
          price: 20,
          playtimeHours: 7,
          mainStoryHours: 8,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 1, 2),
          gameName: 'Short Unplayed',
          gameStatus: SteamGameStatus.open,
          price: 5,
          mainStoryHours: 4,
        ),
      ], currentDate: DateTime(2026, 5, 24));

      final almostDone = insights.backlogPriority.firstWhere((item) {
        return item.purchase.gameName == 'Almost Done';
      });
      final shortUnplayed = insights.backlogPriority.firstWhere((item) {
        return item.purchase.gameName == 'Short Unplayed';
      });

      expect(almostDone.estimatedLengthHours, 8);
      expect(almostDone.estimatedProgress, closeTo(0.875, 0.0001));
      expect(almostDone.reasons, contains(SteamInsightReason.nearlyFinished));
      expect(shortUnplayed.reasons, contains(SteamInsightReason.shortGame));
      expect(shortUnplayed.reasons, contains(SteamInsightReason.noPlaytime));
    });

    test('treats paused games as resumable backlog', () {
      final pausedPurchase = SteamPurchase(
        purchaseDate: DateTime(2025, 12, 1),
        gameName: 'Paused Game',
        gameStatus: SteamGameStatus.paused,
        price: 25,
        playtimeHours: 6,
      );
      final insights = SteamInsights([
        pausedPurchase,
        SteamPurchase(
          purchaseDate: DateTime(2025, 1, 1),
          gameName: 'Finished Game',
          gameStatus: SteamGameStatus.completed,
          price: 15,
          playtimeHours: 8,
        ),
      ], currentDate: DateTime(2026, 5, 24));

      final pausedInsight = insights.backlogPriority.single;

      expect(insights.backlogGames, contains(pausedPurchase));
      expect(insights.startedBacklog.single.purchase, pausedPurchase);
      expect(pausedInsight.reasons, contains(SteamInsightReason.paused));
      expect(insights.completionRate, 0.5);
    });

    test('hides snoozed games from backlog priority until the snooze date', () {
      final hiddenPurchase = SteamPurchase(
        purchaseDate: DateTime(2024, 1, 1),
        gameName: 'Hidden Backlog',
        gameStatus: SteamGameStatus.open,
        backlogPrioritySnoozedUntil: DateTime(2026, 6, 7),
        price: 100,
      );
      final visiblePurchase = SteamPurchase(
        purchaseDate: DateTime(2025, 1, 1),
        gameName: 'Visible Backlog',
        gameStatus: SteamGameStatus.open,
        price: 10,
      );
      final expiredPurchase = SteamPurchase(
        purchaseDate: DateTime(2023, 1, 1),
        gameName: 'Expired Snooze',
        gameStatus: SteamGameStatus.open,
        backlogPrioritySnoozedUntil: DateTime(2026, 5, 24),
        price: 20,
      );
      final currentInsights = SteamInsights([
        hiddenPurchase,
        visiblePurchase,
        expiredPurchase,
      ], currentDate: DateTime(2026, 5, 24));
      final dueInsights = SteamInsights([
        hiddenPurchase,
        visiblePurchase,
        expiredPurchase,
      ], currentDate: DateTime(2026, 6, 7));

      expect(
        currentInsights.backlogPriority.map((item) => item.purchase.gameName),
        containsAll(['Visible Backlog', 'Expired Snooze']),
      );
      expect(
        currentInsights.backlogPriority.map((item) => item.purchase.gameName),
        isNot(contains('Hidden Backlog')),
      );
      expect(
        dueInsights.backlogPriority.map((item) => item.purchase.gameName),
        contains('Hidden Backlog'),
      );
    });
  });
}

List<SteamPurchase> _buildInsightPurchases() {
  return [
    SteamPurchase(
      purchaseDate: DateTime(2023, 1, 10),
      gameName: 'Big Backlog',
      gameStatus: SteamGameStatus.open,
      price: 50,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2023, 2, 10),
      purchaseType: SteamPurchaseType.dlc,
      gameName: 'Big Backlog',
      dlcName: 'Expansion',
      price: 10,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2025, 10, 1),
      gameName: 'Started Backlog',
      gameStatus: SteamGameStatus.active,
      price: 20,
      playtimeHours: 2,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2026, 1, 1),
      gameName: 'Finished Game',
      gameStatus: SteamGameStatus.completed,
      price: 8,
      playtimeHours: 6,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2024, 6, 1),
      gameName: 'Dropped Game',
      gameStatus: SteamGameStatus.abandoned,
      price: 30,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2022, 3, 1),
      gameName: 'Endless Game',
      gameStatus: SteamGameStatus.endless,
      price: 12,
      playtimeHours: 200,
    ),
  ];
}
