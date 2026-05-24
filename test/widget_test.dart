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

  _InMemoryPurchaseRepository([this.purchases = const []]);

  @override
  Future<List<SteamPurchase>> getAllPurchases() async {
    return purchases;
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
  });
}
