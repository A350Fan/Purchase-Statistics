// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/steam_collection_repository.dart';
import 'package:purchase_statistics/models/collection_item.dart';
import 'package:purchase_statistics/models/steam_collection.dart';
import 'package:purchase_statistics/models/steam_purchase.dart';
import 'package:purchase_statistics/screens/collections_tab.dart';

void main() {
  testWidgets('collection purchase picker hides dlcs by default', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 5, 24);
    final repository = _FakeCollectionRepository();
    final collection = SteamCollection(
      id: 1,
      name: 'Favorites',
      createdAt: now,
    );
    final purchases = [
      SteamPurchase(
        id: 1,
        purchaseDate: now,
        gameName: 'Portal 2',
        price: 9.99,
      ),
      SteamPurchase(
        id: 2,
        purchaseDate: now,
        purchaseType: SteamPurchaseType.dlc,
        gameName: 'Portal 2',
        dlcName: 'Soundtrack',
        price: 1.99,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: CollectionDetailScreen(
          collection: collection,
          repository: repository,
          purchases: purchases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_link));
    await tester.pumpAndSettle();

    expect(find.text('Portal 2'), findsOneWidget);
    expect(find.text('Portal 2: Soundtrack'), findsNothing);

    await tester.tap(find.text('Alle'));
    await tester.pumpAndSettle();

    expect(find.text('Portal 2'), findsOneWidget);
    expect(find.text('Portal 2: Soundtrack'), findsOneWidget);

    await tester.tap(find.text('DLCs'));
    await tester.pumpAndSettle();

    expect(find.text('Portal 2'), findsNothing);
    expect(find.text('Portal 2: Soundtrack'), findsOneWidget);
  });
}

class _FakeCollectionRepository extends SteamCollectionRepository {
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
}
