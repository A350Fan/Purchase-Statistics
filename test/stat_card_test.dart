import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steam_stats_app/widgets/stat_card.dart';

void main() {
  testWidgets('renders without overflow in a compact dashboard grid cell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: const Scaffold(
          body: SizedBox(
            width: 295,
            height: 115,
            child: StatCard(title: 'Gesamtausgaben', value: '0,00 €'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
