// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:purchase_statistics/screens/purchase_filters.dart';

void main() {
  test('PurchaseFilters matches all selected filter criteria', () {
    final filters = PurchaseFilters(
      purchaseType: PurchaseTypeFilterOption.games,
      statuses: {SteamGameStatus.open},
      year: 2026,
      minPrice: 5,
      maxPrice: 10,
      playtime: PurchasePlaytimeFilterOption.withoutPlaytime,
      discount: PurchaseDiscountFilterOption.withDiscount,
    );

    expect(
      filters.matches(
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.open,
          price: 9.99,
          originalPrice: 19.99,
        ),
      ),
      isTrue,
    );

    expect(
      filters.matches(
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          purchaseType: SteamPurchaseType.dlc,
          gameName: 'Portal 2',
          dlcName: 'Soundtrack',
          price: 9.99,
          originalPrice: 19.99,
        ),
      ),
      isFalse,
    );

    expect(
      filters.matches(
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Stardew Valley',
          gameStatus: SteamGameStatus.completed,
          price: 9.99,
          originalPrice: 19.99,
        ),
      ),
      isFalse,
    );

    expect(
      filters.matches(
        SteamPurchase(
          purchaseDate: DateTime(2025, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.open,
          price: 9.99,
          originalPrice: 19.99,
        ),
      ),
      isFalse,
    );

    expect(
      filters.matches(
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.open,
          price: 4.99,
          originalPrice: 19.99,
        ),
      ),
      isFalse,
    );

    expect(
      filters.matches(
        SteamPurchase(
          purchaseDate: DateTime(2026, 5, 1),
          gameName: 'Portal 2',
          gameStatus: SteamGameStatus.open,
          price: 9.99,
          originalPrice: 19.99,
          playtimeHours: 2,
        ),
      ),
      isFalse,
    );
  });
}
