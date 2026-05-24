import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/logic/steam_goals.dart';
import 'package:purchase_statistics/models/steam_goal_settings.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';

void main() {
  group('SteamGoalsOverview', () {
    test('evaluates spending projection and backlog targets', () {
      final overview = SteamGoalsOverview(
        purchases: _buildGoalPurchases(),
        settings: const SteamGoalSettings(
          annualSpendingLimit: 100,
          backlogLimit: 2,
          unplayedBacklogLimit: 1,
          unplayedBacklogValueLimit: 70,
          completionRateTarget: 0.75,
        ),
        year: 2026,
        currentDate: DateTime(2026, 5, 24),
      );

      expect(overview.annualSpending, 90);
      expect(overview.projectedAnnualSpending, greaterThan(100));
      expect(overview.annualSpendingGoal.state, SteamGoalState.atRisk);

      expect(overview.backlogCount, 2);
      expect(overview.backlogGoal.state, SteamGoalState.onTrack);

      expect(overview.unplayedBacklogCount, 1);
      expect(overview.unplayedBacklogGoal.state, SteamGoalState.onTrack);

      expect(overview.unplayedBacklogValue, 70);
      expect(overview.unplayedBacklogValueGoal.state, SteamGoalState.onTrack);

      expect(overview.completionRate, 0.5);
      expect(overview.completionRateGoal.state, SteamGoalState.offTrack);
    });

    test('keeps past annual spending goals based on actual spending', () {
      final overview = SteamGoalsOverview(
        purchases: _buildGoalPurchases(),
        settings: const SteamGoalSettings(annualSpendingLimit: 50),
        year: 2025,
        currentDate: DateTime(2026, 5, 24),
      );

      expect(overview.annualSpending, 30);
      expect(overview.projectedAnnualSpending, isNull);
      expect(overview.annualSpendingGoal.state, SteamGoalState.onTrack);
    });

    test('marks unset goals without progress', () {
      final overview = SteamGoalsOverview(
        purchases: _buildGoalPurchases(),
        settings: const SteamGoalSettings(),
        year: 2026,
        currentDate: DateTime(2026, 5, 24),
      );

      expect(overview.backlogGoal.state, SteamGoalState.unset);
      expect(overview.backlogGoal.progress, isNull);
    });
  });
}

List<SteamPurchase> _buildGoalPurchases() {
  return [
    SteamPurchase(
      purchaseDate: DateTime(2026, 1, 10),
      gameName: 'Big Backlog',
      gameStatus: SteamGameStatus.open,
      price: 60,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2026, 2, 10),
      purchaseType: SteamPurchaseType.dlc,
      gameName: 'Big Backlog',
      dlcName: 'Expansion',
      price: 10,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2026, 3, 10),
      gameName: 'Started Backlog',
      gameStatus: SteamGameStatus.active,
      price: 20,
      playtimeHours: 3,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2026, 4, 10),
      gameName: 'Finished Game',
      gameStatus: SteamGameStatus.completed,
      price: 0,
      playtimeHours: 8,
    ),
    SteamPurchase(
      purchaseDate: DateTime(2025, 6, 10),
      gameName: 'Past Game',
      gameStatus: SteamGameStatus.completed,
      price: 30,
      playtimeHours: 4,
    ),
  ];
}
