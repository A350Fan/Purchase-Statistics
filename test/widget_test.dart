import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:steam_purchase_statistics/main.dart';

void main() {
  testWidgets('shows the Steam Purchase Statistics app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SteamStatsApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Steam Stats'), findsOneWidget);
    expect(find.text('Kauf'), findsOneWidget);
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

    await tester.pumpWidget(const SteamStatsApp());
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
