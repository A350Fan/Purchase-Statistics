import 'package:flutter_test/flutter_test.dart';
import 'package:steam_purchase_statistics/data/steam_purchase_csv.dart';
import 'package:steam_purchase_statistics/models/steam_purchase.dart';

void main() {
  group('SteamPurchaseCsv', () {
    test('encodes and decodes purchases with quoted values', () {
      final csv = SteamPurchaseCsv.encode([
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 22),
          purchaseType: SteamPurchaseType.dlc,
          gameName: 'Portal, Episode "Two"',
          edition: 'Deluxe Edition',
          dlcName: 'Soundtrack, "Plus"',
          price: 3.99,
          originalPrice: 19.99,
          playtimeHours: 12.5,
          note: 'Summer sale\nWorth it',
        ),
      ]);

      expect(csv, contains('"Portal, Episode ""Two"""'));
      expect(csv, contains('"Soundtrack, ""Plus"""'));

      final purchases = SteamPurchaseCsv.decode(csv);

      expect(purchases, hasLength(1));
      expect(purchases.single.purchaseDate, DateTime(2026, 5, 22));
      expect(purchases.single.purchaseType, SteamPurchaseType.dlc);
      expect(purchases.single.gameName, 'Portal, Episode "Two"');
      expect(purchases.single.edition, 'Deluxe Edition');
      expect(purchases.single.dlcName, 'Soundtrack, "Plus"');
      expect(purchases.single.price, 3.99);
      expect(purchases.single.originalPrice, 19.99);
      expect(purchases.single.playtimeHours, 12.5);
      expect(purchases.single.note, 'Summer sale\nWorth it');
    });

    test(
      'decodes semicolon separated csv with german headers and decimals',
      () {
        const csv = '''
Kaufdatum;Spielname;Preis;Originalpreis;Spielzeit;Notiz
22.05.2026;Half-Life;1,99;9,99;3,5;Sale
''';

        final purchases = SteamPurchaseCsv.decode(csv);

        expect(purchases, hasLength(1));
        expect(purchases.single.purchaseDate, DateTime(2026, 5, 22));
        expect(purchases.single.purchaseType, SteamPurchaseType.game);
        expect(purchases.single.gameName, 'Half-Life');
        expect(purchases.single.edition, isNull);
        expect(purchases.single.dlcName, isNull);
        expect(purchases.single.price, 1.99);
        expect(purchases.single.originalPrice, 9.99);
        expect(purchases.single.playtimeHours, 3.5);
        expect(purchases.single.note, 'Sale');
      },
    );

    test('decodes dlc purchases with edition from german headers', () {
      const csv = '''
Kaufdatum;Kaufart;Spielname;Edition;DLC;Preis
22.05.2026;DLC;Civilization VI;Anthology;Gathering Storm;9,99
''';

      final purchases = SteamPurchaseCsv.decode(csv);

      expect(purchases, hasLength(1));
      expect(purchases.single.purchaseType, SteamPurchaseType.dlc);
      expect(purchases.single.gameName, 'Civilization VI');
      expect(purchases.single.edition, 'Anthology');
      expect(purchases.single.dlcName, 'Gathering Storm');
      expect(purchases.single.price, 9.99);
    });

    test('throws a descriptive exception for invalid rows', () {
      const csv = '''
purchase_date,game_name,price
2026-05-22,Half-Life,-1.00
''';

      expect(
        () => SteamPurchaseCsv.decode(csv),
        throwsA(isA<SteamPurchaseCsvException>()),
      );
    });
  });
}
