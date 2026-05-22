import 'package:flutter_test/flutter_test.dart';
import 'package:steam_stats_app/logic/steam_statistics.dart';
import 'package:steam_stats_app/models/steam_purchase.dart';

void main() {
  group('SteamStatistics', () {
    test('builds annual rows with cumulative spending and known discounts', () {
      final stats = SteamStatistics([
        SteamPurchase(
          purchaseDate: DateTime(2024, 1, 10),
          gameName: 'Discounted game',
          price: 10,
          originalPrice: 20,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2024, 7, 3),
          gameName: 'Unknown discount game',
          price: 30,
        ),
      ], currentDate: DateTime(2026, 5, 22));

      expect(stats.years, [2024, 2025, 2026]);

      final rows = stats.annualStatistics;

      expect(rows[0].year, 2024);
      expect(rows[0].spending, 40);
      expect(rows[0].averageDiscount, closeTo(0.5, 0.0001));
      expect(rows[0].cumulativeSpending, 40);

      expect(rows[1].year, 2025);
      expect(rows[1].spending, 0);
      expect(rows[1].averageDiscount, isNull);
      expect(rows[1].cumulativeSpending, 40);

      expect(rows[2].year, 2026);
      expect(rows[2].spending, 0);
      expect(rows[2].cumulativeSpending, 40);

      expect(stats.annualSummary.averageSpending, closeTo(40 / 3, 0.0001));
      expect(stats.annualSummary.totalOriginalPrice, 50);
    });

    test('builds quarterly rows and projects the current year', () {
      final stats = SteamStatistics([
        SteamPurchase(
          purchaseDate: DateTime(2026, 2, 1),
          gameName: 'Q1 game',
          price: 25,
          originalPrice: 100,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 4, 1),
          gameName: 'Q2 game',
          price: 75,
        ),
      ], currentDate: DateTime(2026, 5, 22));

      final rows = stats.quarterlyStatisticsForYear(2026);

      expect(rows[0].quarter, 1);
      expect(rows[0].spending, 25);
      expect(rows[0].averageDiscount, closeTo(0.75, 0.0001));
      expect(rows[0].cumulativeSpending, 25);

      expect(rows[1].quarter, 2);
      expect(rows[1].spending, 75);
      expect(rows[1].averageDiscount, isNull);
      expect(rows[1].cumulativeSpending, 100);

      expect(rows[2].spending, 0);
      expect(rows[2].cumulativeSpending, 100);
      expect(rows[3].spending, 0);
      expect(rows[3].cumulativeSpending, 100);

      final summary = stats.quarterlySummaryForYear(2026);
      final projectedSpending = 100 / 142 * 365;

      expect(summary.isProjected, isTrue);
      expect(summary.actualSpending, 100);
      expect(summary.projectedSpending, closeTo(projectedSpending, 0.0001));
      expect(
        summary.averageQuarterSpending,
        closeTo(projectedSpending / 4, 0.0001),
      );
      expect(summary.averageDiscount, closeTo(0.75, 0.0001));
    });
  });
}
