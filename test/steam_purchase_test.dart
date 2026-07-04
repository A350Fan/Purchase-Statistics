// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';

void main() {
  group('SteamPurchase', () {
    test('removes the associated game prefix from DLC display names', () {
      final purchase = SteamPurchase(
        purchaseDate: DateTime(2026, 5, 24),
        purchaseType: SteamPurchaseType.dlc,
        gameName: 'Train Simulator',
        dlcName:
            'Train Simulator: Mittenwaldbahn: Garmisch-Partenkirchen - '
            'Innsbruck Route Add-On',
        price: 9.99,
      );

      expect(
        purchase.displayName,
        'Train Simulator: Mittenwaldbahn: Garmisch-Partenkirchen - '
        'Innsbruck Route Add-On',
      );
    });

    test('keeps DLC names that do not start with the associated game', () {
      expect(
        SteamPurchase.cleanDlcNameForGame(
          gameName: 'Portal 2',
          dlcName: 'Peer Review',
        ),
        'Peer Review',
      );
    });

    test('stores game status only for game purchases', () {
      final snoozedUntil = DateTime(2026, 6, 7);
      final gamePurchase = SteamPurchase(
        purchaseDate: DateTime(2026, 5, 24),
        gameName: 'Portal 2',
        gameStatus: SteamGameStatus.completed,
        mainStoryHours: 8,
        backlogPrioritySnoozedUntil: snoozedUntil,
        price: 9.99,
      );
      final dlcPurchase = SteamPurchase(
        purchaseDate: DateTime(2026, 5, 24),
        purchaseType: SteamPurchaseType.dlc,
        gameName: 'Portal 2',
        dlcName: 'Soundtrack',
        gameStatus: SteamGameStatus.completed,
        mainStoryHours: 8,
        price: 1.99,
      );

      expect(gamePurchase.toMap()['game_status'], 'completed');
      expect(gamePurchase.toMap()['main_story_hours'], 8);
      expect(
        gamePurchase.toMap()['backlog_priority_snoozed_until'],
        snoozedUntil.toIso8601String(),
      );
      expect(dlcPurchase.toMap()['game_status'], isNull);
      expect(dlcPurchase.toMap()['main_story_hours'], isNull);
      expect(dlcPurchase.toMap()['backlog_priority_snoozed_until'], isNull);
    });

    test('parses and clears backlog priority snooze timestamps', () {
      final snoozedUntil = DateTime(2026, 6, 7);
      final purchase = SteamPurchase.fromMap({
        'id': 1,
        'purchase_date': DateTime(2026, 5, 24).toIso8601String(),
        'purchase_type': 'game',
        'game_name': 'Portal 2',
        'edition': null,
        'dlc_name': null,
        'game_status': 'open',
        'steam_app_id': null,
        'price': 9.99,
        'original_price': null,
        'playtime_hours': null,
        'main_story_hours': null,
        'main_extra_hours': null,
        'completionist_hours': null,
        'backlog_priority_snoozed_until': snoozedUntil.toIso8601String(),
        'note': null,
      });

      expect(purchase.launcher, PurchaseLauncher.steam);
      expect(purchase.backlogPrioritySnoozedUntil, snoozedUntil);
      expect(
        purchase
            .copyWith(backlogPrioritySnoozedUntil: null)
            .backlogPrioritySnoozedUntil,
        isNull,
      );
    });

    test('stores launcher presets and custom values', () {
      final customLauncher = PurchaseLauncher.custom('Battle.net');
      final presetLauncher = PurchaseLauncher.fromStorageValue('Epic Games');
      final msfsMarketplace = PurchaseLauncher.fromStorageValue(
        'MSFS Marketplace',
      );

      expect(presetLauncher, PurchaseLauncher.epicGames);
      expect(customLauncher.isPreset, isFalse);
      expect(customLauncher.label, 'Battle.net');
      expect(msfsMarketplace.isPreset, isFalse);
      expect(msfsMarketplace.label, 'MSFS Marketplace');
    });

    test('clears Steam app ids for non-Steam launchers when serialized', () {
      final purchase = SteamPurchase(
        purchaseDate: DateTime(2026, 5, 24),
        gameName: 'Epic Game',
        launcher: PurchaseLauncher.epicGames,
        steamAppId: 620,
        price: 9.99,
      );

      expect(purchase.toMap()['launcher'], 'epic_games');
      expect(purchase.toMap()['steam_app_id'], isNull);
    });

    test('parses German game status aliases', () {
      expect(
        SteamGameStatus.fromStorageValue('Durchgespielt'),
        SteamGameStatus.completed,
      );
      expect(SteamGameStatus.fromStorageValue('Aktiv'), SteamGameStatus.active);
      expect(
        SteamGameStatus.fromStorageValue('Pausiert'),
        SteamGameStatus.paused,
      );
      expect(SteamGameStatus.fromStorageValue('Alt'), SteamGameStatus.archived);
    });
  });
}
