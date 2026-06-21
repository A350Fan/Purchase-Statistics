// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_game_length_estimate_repository.dart';
import 'package:purchase_statistics/data/steam_store_search_repository.dart';
import 'package:purchase_statistics/models/steam_game_length_estimate.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:purchase_statistics/models/steam_store_search_suggestion.dart';
import 'package:purchase_statistics/screens/add_purchase_screen.dart';

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

  testWidgets('cleans duplicated Steam DLC names while editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddPurchaseScreen(
          initialPurchase: SteamPurchase(
            purchaseDate: DateTime(2026, 5, 1),
            purchaseType: SteamPurchaseType.dlc,
            gameName: 'Train Simulator',
            dlcName:
                'Train Simulator: Mittenwaldbahn: Garmisch-Partenkirchen - '
                'Innsbruck Route Add-On',
            steamAppId: 448192,
            price: 9.99,
          ),
        ),
      ),
    );

    final dlcField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );

    expect(
      dlcField.controller?.text,
      'Mittenwaldbahn: Garmisch-Partenkirchen - Innsbruck Route Add-On',
    );
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

  testWidgets('matches Steam suggestions when legal marks are omitted', (
    tester,
  ) async {
    const title = 'Train Sim World\u00ae 2';
    final steamSearchSource = _FakeSteamSearchSource([
      const SteamStoreSearchSuggestion(appId: 1282590, name: title),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AddPurchaseScreen(steamSearchSource: steamSearchSource),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'Train Sim World 2',
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    expect(steamSearchSource.queries, ['Train Sim World 2']);
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('selects Steam suggestions and returns the Steam app id', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    PurchaseEditorResult? result;
    final steamSearchSource = _FakeSteamSearchSource([
      const SteamStoreSearchSuggestion(
        appId: 2537590,
        name: 'Microsoft Flight Simulator 2024',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<PurchaseEditorResult>(
                        MaterialPageRoute(
                          builder: (context) => AddPurchaseScreen(
                            steamSearchSource: steamSearchSource,
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'flight');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.tap(find.text('Microsoft Flight Simulator 2024'));
    await tester.pump();

    expect(find.text('2537590'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), '59.99');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.purchase.gameName, 'Microsoft Flight Simulator 2024');
    expect(result!.purchase.steamAppId, 2537590);
  });

  testWidgets('returns the selected game status for game purchases', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    PurchaseEditorResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<PurchaseEditorResult>(
                        MaterialPageRoute(
                          builder: (context) => const AddPurchaseScreen(),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Portal 2');
    await tester.tap(find.text('Kein Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausiert').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(3), '9.99');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.purchase.gameStatus, SteamGameStatus.paused);
  });

  testWidgets('returns manual game length estimates', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    PurchaseEditorResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<PurchaseEditorResult>(
                        MaterialPageRoute(
                          builder: (context) => const AddPurchaseScreen(),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Portal 2');
    await tester.enterText(find.byType(TextFormField).at(3), '9.99');
    await tester.tap(find.text('Spielzeit'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Spielzeit optional'),
      '4,2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hauptstory optional'),
      '8',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hauptstory + Extras optional'),
      '12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Komplett optional'),
      '20',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.purchase.playtimeHours, 4.2);
    expect(result!.purchase.mainStoryHours, 8);
    expect(result!.purchase.mainExtraHours, 12);
    expect(result!.purchase.completionistHours, 20);
  });

  testWidgets('prefills game length estimates from the background database', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    PurchaseEditorResult? result;
    final lengthEstimateRepository = _FakeLengthEstimateRepository(
      const SteamGameLengthEstimate(
        gameName: 'Portal 2',
        steamAppId: 620,
        mainStoryHours: 8,
        mainExtraHours: 12,
        completionistHours: 20,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<PurchaseEditorResult>(
                        MaterialPageRoute(
                          builder: (context) => AddPurchaseScreen(
                            lengthEstimateRepository: lengthEstimateRepository,
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Portal 2');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(3), '9.99');
    await tester.tap(find.text('Spielzeit'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Hauptstory optional'),
          )
          .controller
          ?.text,
      '8.0',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Hauptstory + Extras optional'),
          )
          .controller
          ?.text,
      '12.0',
    );

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.purchase.mainStoryHours, 8);
    expect(result!.purchase.mainExtraHours, 12);
    expect(result!.purchase.completionistHours, 20);
  });

  testWidgets('strips the associated game name from selected Steam DLCs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    PurchaseEditorResult? result;
    final steamSearchSource = _FakeSteamSearchSource([
      const SteamStoreSearchSuggestion(
        appId: 448192,
        name:
            'Train Simulator: Mittenwaldbahn: Garmisch-Partenkirchen - '
            'Innsbruck Route Add-On',
        itemType: SteamStoreItemType.dlc,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<PurchaseEditorResult>(
                        MaterialPageRoute(
                          builder: (context) => AddPurchaseScreen(
                            steamSearchSource: steamSearchSource,
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DLC'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Train Simulator');
    await tester.enterText(find.byType(TextFormField).at(1), 'mittenwald');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.tap(
      find.text(
        'Train Simulator: Mittenwaldbahn: Garmisch-Partenkirchen - '
        'Innsbruck Route Add-On',
      ),
    );
    await tester.pump();

    expect(find.text('448192'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(4), '9.99');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.purchase.gameName, 'Train Simulator');
    expect(
      result!.purchase.dlcName,
      'Mittenwaldbahn: Garmisch-Partenkirchen - Innsbruck Route Add-On',
    );
    expect(
      result!.purchase.displayName,
      'Train Simulator: Mittenwaldbahn: Garmisch-Partenkirchen - '
      'Innsbruck Route Add-On',
    );
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

class _FakeLengthEstimateRepository extends SteamGameLengthEstimateRepository {
  final SteamGameLengthEstimate? estimate;

  _FakeLengthEstimateRepository(this.estimate);

  @override
  Future<SteamGameLengthEstimate?> findEstimate({
    int? steamAppId,
    String? gameName,
  }) async {
    return estimate;
  }
}
