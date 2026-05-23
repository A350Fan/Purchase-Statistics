import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:purchase_statistics/data/steam_collection_repository.dart';
import 'package:purchase_statistics/data/steam_purchase_repository.dart';
import 'package:purchase_statistics/main.dart';
import 'package:purchase_statistics/models/collection_item.dart';
import 'package:purchase_statistics/models/steam_collection.dart';
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
  @override
  Future<List<SteamPurchase>> getAllPurchases() async {
    return [];
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
  Future<List<CollectionItem>> getItemsForCollection(int collectionId) async {
    return [];
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

SteamStatsApp _buildTestApp([_InMemorySettingsStore? store]) {
  return SteamStatsApp(
    settingsController: AppSettingsController(
      store: store ?? _InMemorySettingsStore(),
    ),
    purchaseRepository: _InMemoryPurchaseRepository(),
    collectionRepository: _InMemoryCollectionRepository(),
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

    await tester.pumpWidget(_buildTestApp());
    await tester.pump(const Duration(seconds: 1));

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
