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
  });
}
