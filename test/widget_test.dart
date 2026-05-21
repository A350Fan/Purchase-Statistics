import 'package:flutter_test/flutter_test.dart';

import 'package:steam_stats_app/main.dart';

void main() {
  testWidgets('shows the Steam Stats app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SteamStatsApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Steam Stats'), findsOneWidget);
    expect(find.text('Kauf'), findsOneWidget);
  });
}
