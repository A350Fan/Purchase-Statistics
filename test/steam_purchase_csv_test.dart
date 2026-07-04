// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_purchase_csv.dart';
import 'package:purchase_statistics/models/steam_game_length_estimate.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';

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
          steamAppId: 620,
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
      expect(purchases.single.gameStatus, isNull);
      expect(purchases.single.launcher, PurchaseLauncher.steam);
      expect(purchases.single.steamAppId, 620);
      expect(purchases.single.price, 3.99);
      expect(purchases.single.originalPrice, 19.99);
      expect(purchases.single.playtimeHours, 12.5);
      expect(purchases.single.mainStoryHours, isNull);
      expect(purchases.single.mainExtraHours, isNull);
      expect(purchases.single.completionistHours, isNull);
      expect(purchases.single.note, 'Summer sale\nWorth it');
    });

    test('encodes and decodes game length estimates for game purchases', () {
      final csv = SteamPurchaseCsv.encode([
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 22),
          gameName: 'Portal 2',
          price: 3.99,
          playtimeHours: 4.2,
          mainStoryHours: 8,
          mainExtraHours: 10.5,
          completionistHours: 14,
        ),
      ]);

      final purchases = SteamPurchaseCsv.decode(csv);

      expect(purchases.single.playtimeHours, 4.2);
      expect(purchases.single.mainStoryHours, 8);
      expect(purchases.single.mainExtraHours, 10.5);
      expect(purchases.single.completionistHours, 14);
    });

    test('encodes shareable length estimates without purchase stats', () {
      final csv = SteamPurchaseCsv.encodeLengthEstimates([
        const SteamGameLengthEstimate(
          gameName: 'Portal 2',
          steamAppId: 620,
          mainStoryHours: 8,
          mainExtraHours: 10.5,
          completionistHours: 14,
        ),
        const SteamGameLengthEstimate(gameName: 'No estimate'),
      ]);

      final nonEmptyLines = csv
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      expect(
        csv,
        startsWith(
          'game_name,steam_app_id,main_story_hours,main_extra_hours,completionist_hours',
        ),
      );
      expect(csv, contains('Portal 2,620,8.00,10.50,14.00'));
      expect(nonEmptyLines, hasLength(2));
      expect(csv, isNot(contains('purchase_date')));
      expect(csv, isNot(contains('3.99')));
      expect(csv, isNot(contains('completed')));
      expect(csv, isNot(contains('private note')));
      expect(csv, isNot(contains('Soundtrack')));
    });

    test('decodes shareable length estimate csv as background data', () {
      const csv = '''
game_name,steam_app_id,main_story_hours,main_extra_hours,completionist_hours,price,note
Portal 2,620,8,10.5,14,3.99,private note
No estimate,123,,,,
''';

      final estimates = SteamPurchaseCsv.decodeLengthEstimates(csv);

      expect(estimates, hasLength(1));
      expect(estimates.single.gameName, 'Portal 2');
      expect(estimates.single.steamAppId, 620);
      expect(estimates.single.mainStoryHours, 8);
      expect(estimates.single.mainExtraHours, 10.5);
      expect(estimates.single.completionistHours, 14);
    });

    test(
      'decodes semicolon separated csv with german headers and decimals',
      () {
        const csv = '''
Kaufdatum;Spielname;Status;Preis;Originalpreis;Spielzeit;Hauptstory;Hauptstory Extras;Komplett;Notiz
22.05.2026;Half-Life;Aktiv;1,99;9,99;3,5;7;9,5;12;Sale
''';

        final purchases = SteamPurchaseCsv.decode(csv);

        expect(purchases, hasLength(1));
        expect(purchases.single.purchaseDate, DateTime(2026, 5, 22));
        expect(purchases.single.purchaseType, SteamPurchaseType.game);
        expect(purchases.single.launcher, PurchaseLauncher.steam);
        expect(purchases.single.gameName, 'Half-Life');
        expect(purchases.single.gameStatus, SteamGameStatus.active);
        expect(purchases.single.edition, isNull);
        expect(purchases.single.dlcName, isNull);
        expect(purchases.single.price, 1.99);
        expect(purchases.single.originalPrice, 9.99);
        expect(purchases.single.playtimeHours, 3.5);
        expect(purchases.single.mainStoryHours, 7);
        expect(purchases.single.mainExtraHours, 9.5);
        expect(purchases.single.completionistHours, 12);
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
      expect(purchases.single.launcher, PurchaseLauncher.steam);
      expect(purchases.single.gameName, 'Civilization VI');
      expect(purchases.single.edition, 'Anthology');
      expect(purchases.single.dlcName, 'Gathering Storm');
      expect(purchases.single.price, 9.99);
    });

    test('encodes and decodes optional game statuses for game purchases', () {
      final csv = SteamPurchaseCsv.encode([
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 22),
          gameName: 'Half-Life',
          gameStatus: SteamGameStatus.paused,
          price: 1.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 23),
          purchaseType: SteamPurchaseType.dlc,
          gameName: 'Half-Life',
          dlcName: 'Soundtrack',
          price: 0.99,
        ),
      ]);

      expect(csv, startsWith('purchase_date,purchase_type,launcher'));
      expect(csv, contains('2026-05-22,game,Steam,paused,Half-Life'));
      expect(csv, contains('2026-05-23,dlc,Steam,,Half-Life'));

      final purchases = SteamPurchaseCsv.decode(csv);

      expect(purchases[0].gameStatus, SteamGameStatus.paused);
      expect(purchases[1].gameStatus, isNull);
    });

    test('encodes and decodes preset and custom launchers', () {
      final csv = SteamPurchaseCsv.encode([
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 22),
          launcher: PurchaseLauncher.epicGames,
          gameName: 'Alan Wake 2',
          price: 19.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 23),
          launcher: PurchaseLauncher.custom('Battle.net'),
          gameName: 'Diablo',
          price: 9.99,
        ),
      ]);

      expect(csv, contains('Epic Games'));
      expect(csv, contains('Battle.net'));

      final purchases = SteamPurchaseCsv.decode(csv);

      expect(purchases[0].launcher, PurchaseLauncher.epicGames);
      expect(purchases[1].launcher, PurchaseLauncher.custom('Battle.net'));
    });

    test('escapes spreadsheet formulas in exported text fields', () {
      final csv = SteamPurchaseCsv.encode([
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 22),
          gameName: '=HYPERLINK("https://example.invalid")',
          edition: '+Collector',
          price: 1.99,
          note: ' @import',
        ),
      ]);

      expect(csv, contains('''"'=HYPERLINK(""https://example.invalid"")"'''));
      expect(csv, contains(",'+Collector,"));
      expect(csv, contains(",' @import"));
    });

    test('rejects CSV files with too many rows', () {
      final buffer = StringBuffer('purchase_date,game_name,price\n');

      for (var index = 0; index <= SteamPurchaseCsv.maxImportRows; index++) {
        buffer.writeln('2026-05-22,Game $index,1.99');
      }

      expect(
        () => SteamPurchaseCsv.decode(buffer.toString()),
        throwsA(isA<SteamPurchaseCsvException>()),
      );
    });

    test('allows zero original price', () {
      const csv = '''
purchase_date,game_name,price,original_price
2026-05-22,Free base game,0.00,0.00
''';

      final purchases = SteamPurchaseCsv.decode(csv);

      expect(purchases, hasLength(1));
      expect(purchases.single.price, 0);
      expect(purchases.single.originalPrice, 0);
      expect(purchases.single.discount, isNull);
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
