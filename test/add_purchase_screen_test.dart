import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_purchase_statistics/data/steam_store_search_repository.dart';
import 'package:steam_purchase_statistics/models/steam_purchase.dart';
import 'package:steam_purchase_statistics/models/steam_store_search_suggestion.dart';
import 'package:steam_purchase_statistics/screens/add_purchase_screen.dart';

void main() {
  testWidgets('suggests saved game names while typing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddPurchaseScreen(
          existingPurchases: [
            SteamPurchase(
              purchaseDate: DateTime(2026, 5, 1),
              gameName: 'Portal 2',
              price: 9.99,
            ),
            SteamPurchase(
              purchaseDate: DateTime(2026, 5, 2),
              gameName: 'Half-Life',
              price: 9.99,
            ),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'por');
    await tester.pump();

    expect(find.text('Portal 2'), findsOneWidget);
    expect(find.text('Half-Life'), findsNothing);
  });

  testWidgets('suggests saved dlc names while typing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddPurchaseScreen(
          existingPurchases: [
            SteamPurchase(
              purchaseDate: DateTime(2026, 5, 1),
              purchaseType: SteamPurchaseType.dlc,
              gameName: 'Civilization VI',
              dlcName: 'Gathering Storm',
              price: 9.99,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('DLC'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'storm');
    await tester.pump();

    expect(find.text('Gathering Storm'), findsOneWidget);
  });

  testWidgets('shows Steam suggestions after the debounce delay', (
    tester,
  ) async {
    final steamSearchSource = _FakeSteamSearchSource([
      const SteamStoreSearchSuggestion(
        appId: 2537590,
        name: 'Microsoft Flight Simulator 2024',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AddPurchaseScreen(steamSearchSource: steamSearchSource),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'flight');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    expect(steamSearchSource.queries, ['flight']);
    expect(find.text('Microsoft Flight Simulator 2024'), findsOneWidget);
    expect(find.text('Steam'), findsOneWidget);
  });
}

class _FakeSteamSearchSource implements SteamStoreSearchSource {
  final List<SteamStoreSearchSuggestion> suggestions;
  final List<String> queries = [];

  _FakeSteamSearchSource(this.suggestions);

  @override
  Future<List<SteamStoreSearchSuggestion>> search({
    required String query,
    required SteamPurchaseType purchaseType,
    required String language,
    required String countryCode,
    String? associatedGameName,
  }) async {
    queries.add(query);
    return suggestions;
  }
}
