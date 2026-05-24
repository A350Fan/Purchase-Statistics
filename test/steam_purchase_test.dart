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
      final gamePurchase = SteamPurchase(
        purchaseDate: DateTime(2026, 5, 24),
        gameName: 'Portal 2',
        gameStatus: SteamGameStatus.completed,
        mainStoryHours: 8,
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
      expect(dlcPurchase.toMap()['game_status'], isNull);
      expect(dlcPurchase.toMap()['main_story_hours'], isNull);
    });

    test('parses German game status aliases', () {
      expect(
        SteamGameStatus.fromStorageValue('Durchgespielt'),
        SteamGameStatus.completed,
      );
      expect(SteamGameStatus.fromStorageValue('Aktiv'), SteamGameStatus.active);
      expect(SteamGameStatus.fromStorageValue('Alt'), SteamGameStatus.archived);
    });
  });
}
