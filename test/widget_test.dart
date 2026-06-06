import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:purchase_statistics/data/steam_collection_repository.dart';
import 'package:purchase_statistics/data/steam_goal_repository.dart';
import 'package:purchase_statistics/data/steam_purchase_repository.dart';
import 'package:purchase_statistics/main.dart';
import 'package:purchase_statistics/models/collection_item.dart';
import 'package:purchase_statistics/models/steam_collection.dart';
import 'package:purchase_statistics/models/steam_game_metadata.dart';
import 'package:purchase_statistics/models/steam_goal_settings.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:purchase_statistics/settings/app_settings.dart';
import 'package:purchase_statistics/settings/app_settings_controller.dart';
import 'package:purchase_statistics/settings/settings_repository.dart';

class _InMemorySettingsStore implements AppSettingsStore {
  AppSettings settings;

  _InMemorySettingsStore() : settings = const AppSettings();

  @override
  Future<AppSettings> loadSettings() async {
    return settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}

class _InMemoryPurchaseRepository extends SteamPurchaseRepository {
  final List<SteamPurchase> purchases;

  _InMemoryPurchaseRepository([List<SteamPurchase> purchases = const []])
    : purchases = [...purchases];

  @override
  Future<List<SteamPurchase>> getAllPurchases() async {
    return List.unmodifiable(purchases);
  }

  @override
  Future<void> updatePurchase(SteamPurchase purchase) async {
    final id = purchase.id;

    if (id == null) {
      throw ArgumentError('Cannot update purchase without id.');
    }

    final index = purchases.indexWhere((candidate) => candidate.id == id);

    if (index < 0) {
      throw StateError('Purchase not found: $id');
    }

    // Tests spiegeln das echte Repository: ein Update ersetzt die gespeicherte
    // Zeile, danach liest der HomeScreen die Liste neu.
    purchases[index] = purchase;
  }
}

class _InMemoryCollectionRepository extends SteamCollectionRepository {
  @override
  Future<List<SteamCollection>> getCollections() async {
    return [];
  }

  @override
  Future<Map<int, int>> getItemCountsByCollection() async {
    return {};
  }

  @override
  Future<int> countPurchasesForAutomaticCollection(
    SteamCollection collection,
  ) async {
    return 0;
  }

  @override
  Future<List<String>> getAvailableMetadataRuleValues(
    SteamMetadataField field,
  ) async {
    return [];
  }

  @override
  Future<List<SteamPurchase>> getPurchasesForAutomaticCollection(
    SteamCollection collection,
  ) async {
    return [];
  }

  @override
  Future<int> insertCollection(SteamCollection collection) async {
    return 1;
  }

  @override
  Future<int> updateCollection(SteamCollection collection) async {
    return 1;
  }

  @override
  Future<int> deleteCollection(int id) async {
    return 1;
  }

  @override
  Future<List<CollectionItem>> getItemsForCollection(
    int collectionId, {
    SteamCollectionSortMode sortMode = SteamCollectionSortMode.manual,
  }) async {
    return [];
  }

  @override
  Future<Map<int, CollectionPurchaseMetadata>> getPurchaseMetadataByIds(
    Iterable<int> purchaseIds,
  ) async {
    return {};
  }

  @override
  Future<Set<int>> getCollectionIdsForPurchase(int purchaseId) async {
    return {};
  }

  @override
  Future<void> replaceCollectionsForPurchase({
    required int purchaseId,
    required Set<int> collectionIds,
  }) async {}
}

class _InMemoryGoalStore implements SteamGoalStore {
  SteamGoalSettings goals = const SteamGoalSettings();

  _InMemoryGoalStore();

  @override
  Future<SteamGoalSettings> loadGoals() async {
    return goals;
  }

  @override
  Future<void> saveGoals(SteamGoalSettings goals) async {
    this.goals = goals;
  }
}

SteamStatsApp _buildTestApp([
  _InMemorySettingsStore? store,
  List<SteamPurchase> purchases = const [],
  _InMemoryGoalStore? goalStore,
]) {
  return SteamStatsApp(
    settingsController: AppSettingsController(
      store: store ?? _InMemorySettingsStore(),
    ),
    purchaseRepository: _InMemoryPurchaseRepository(purchases),
    collectionRepository: _InMemoryCollectionRepository(),
    goalStore: goalStore ?? _InMemoryGoalStore(),
  );
}

Future<void> _pumpInteractionFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('shows the Purchase Statistics app shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Purchase Statistics'), findsOneWidget);
    expect(find.text('Kauf'), findsOneWidget);
    expect(find.byTooltip('Einstellungen'), findsOneWidget);
  });

  testWidgets('overview fits in a short desktop window', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1116, 610);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _buildTestApp(null, [
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.open,
          price: 9.99,
          originalPrice: 19.99,
        ),
      ]),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });

  testWidgets('snoozes play next recommendations for two weeks', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final repository = _InMemoryPurchaseRepository([
      SteamPurchase(
        id: 1,
        purchaseDate: DateTime(2020, 1, 1),
        gameName: 'Portal 2',
        gameStatus: SteamGameStatus.open,
        price: 59.99,
      ),
    ]);

    await tester.pumpWidget(
      SteamStatsApp(
        settingsController: AppSettingsController(
          store: _InMemorySettingsStore(),
        ),
        purchaseRepository: repository,
        collectionRepository: _InMemoryCollectionRepository(),
        goalStore: _InMemoryGoalStore(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Insights').first);
    await _pumpInteractionFrame(tester);

    expect(find.textContaining('Priorität:'), findsOneWidget);

    await tester.tap(
      find.byTooltip('Für 2 Wochen aus Als Nächstes ausblenden').first,
    );
    await _pumpInteractionFrame(tester);

    expect(
      repository.purchases
          .singleWhere((purchase) => purchase.id == 1)
          .backlogPrioritySnoozedUntil,
      isNotNull,
    );
    expect(find.textContaining('Priorität:'), findsNothing);
    expect(
      find.textContaining('aus Als Nächstes ausgeblendet'),
      findsOneWidget,
    );

    await tester.tap(find.text('Rückgängig'));
    await _pumpInteractionFrame(tester);

    expect(
      repository.purchases
          .singleWhere((purchase) => purchase.id == 1)
          .backlogPrioritySnoozedUntil,
      isNull,
    );
    expect(find.textContaining('Priorität:'), findsOneWidget);
  });

  testWidgets('filters purchases from the overview search field', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1400);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _buildTestApp(null, [
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Euro Truck Simulator',
          price: 4.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 2),
          gameName: 'Euro Truck Simulator 2',
          price: 9.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 3),
          gameName: 'Portal 2',
          price: 9.99,
        ),
      ]),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField), 'Euro');
    await tester.pump();

    expect(find.text('Euro Truck Simulator'), findsOneWidget);
    expect(find.text('Euro Truck Simulator 2'), findsOneWidget);
    expect(find.text('Portal 2'), findsNothing);

    await tester.tap(find.byTooltip('Suche löschen'));
    await tester.pump();

    expect(find.text('Portal 2'), findsOneWidget);
  });

  testWidgets('applies advanced purchase filters from the overview', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1400);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _buildTestApp(null, [
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.open,
          price: 9.99,
          originalPrice: 19.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 2),
          gameName: 'Stardew Valley',
          gameStatus: SteamGameStatus.completed,
          price: 4.99,
          originalPrice: 14.99,
          playtimeHours: 120,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 3),
          purchaseType: SteamPurchaseType.dlc,
          gameName: 'Portal 2',
          dlcName: 'Soundtrack',
          price: 2.99,
        ),
      ]),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Filter'));
    await _pumpInteractionFrame(tester);

    await tester.tap(find.text('Offen'));
    await tester.tap(find.text('Anwenden'));
    await _pumpInteractionFrame(tester);

    expect(find.text('Portal 2'), findsOneWidget);
    expect(find.text('Stardew Valley'), findsNothing);
    expect(find.text('Portal 2: Soundtrack'), findsNothing);
    expect(find.text('Filter (1)'), findsOneWidget);

    await tester.tap(find.text('Filter zurücksetzen'));
    await tester.pump();

    expect(find.text('Stardew Valley'), findsOneWidget);
    expect(find.text('Portal 2: Soundtrack'), findsOneWidget);
  });

  testWidgets('purchase filter dialog fits in a narrow viewport', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 850);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(_buildTestApp());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Filter'));
    await _pumpInteractionFrame(tester);

    expect(find.text('Käufe filtern'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings menu changes theme and language', (
    WidgetTester tester,
  ) async {
    final store = _InMemorySettingsStore();

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Einstellungen'));
    await _pumpInteractionFrame(tester);

    expect(find.text('Darstellung'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Währung'), findsOneWidget);
    expect(find.text('Steam-Sync'), findsOneWidget);

    await tester.tap(find.text('Hell'));
    await _pumpInteractionFrame(tester);

    expect(store.settings.themeMode, AppThemeMode.light);

    final settingsContext = tester.element(find.text('Darstellung'));
    expect(Theme.of(settingsContext).brightness, Brightness.light);

    await tester.tap(find.text('Euro (€)'));
    await _pumpInteractionFrame(tester);

    await tester.tap(find.text('US-Dollar (\$)').last);
    await _pumpInteractionFrame(tester);

    expect(store.settings.currency, AppCurrency.usd);

    await tester.tap(find.text('Englisch'));
    await _pumpInteractionFrame(tester);

    expect(store.settings.language, AppLanguage.english);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    await tester.ensureVisible(find.text('Steam sync'));
    await _pumpInteractionFrame(tester);

    await tester.enterText(find.byType(TextField).at(0), '76561198000000000');
    await tester.enterText(find.byType(TextField).at(1), 'test-api-key');
    await tester.ensureVisible(find.text('Save Steam settings'));
    await _pumpInteractionFrame(tester);

    await tester.tap(find.text('Save Steam settings'));
    await _pumpInteractionFrame(tester);

    expect(store.settings.steamAccountIdentifier, '76561198000000000');
    expect(store.settings.steamWebApiKey, 'test-api-key');
    expect(store.settings.steamIncludePlayedFreeGames, isTrue);

    await tester.scrollUntilVisible(
      find.text('Open source licenses'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await _pumpInteractionFrame(tester);

    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Open source licenses'), findsOneWidget);

    await tester.tap(find.text('Open source licenses'));
    await _pumpInteractionFrame(tester);

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
