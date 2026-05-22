import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_stats_app/models/steam_purchase.dart';
import 'package:steam_stats_app/screens/charts_tab.dart';

void main() {
  testWidgets('renders the chart panels with purchase data', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: Scaffold(
          body: ChartsTab(
            purchases: [
              SteamPurchase(
                purchaseDate: DateTime(2025, 1, 10),
                gameName: 'Portal',
                price: 5,
                originalPrice: 20,
              ),
              SteamPurchase(
                purchaseDate: DateTime(2025, 5, 10),
                gameName: 'Half-Life',
                price: 8,
                originalPrice: 10,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Diagramme'), findsOneWidget);
    expect(find.text('AUSGABEN PRO JAHR'), findsOneWidget);
    expect(find.text('AUSGABEN PRO QUARTAL'), findsOneWidget);
    expect(find.text('RABATT PRO JAHR'), findsOneWidget);
    expect(find.text('RABATT PRO QUARTAL'), findsOneWidget);
    expect(find.text('GESAMTAUSGABEN'), findsOneWidget);
    expect(find.text('GESAMTAUSGABEN IM GEWÄHLTEN JAHR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
