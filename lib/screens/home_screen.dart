import 'package:flutter/material.dart';

import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  List<SteamPurchase> get testPurchases => [
        SteamPurchase(
          purchaseDate: DateTime(2024, 11, 29),
          gameName: 'Cyberpunk 2077',
          price: 29.99,
          originalPrice: 59.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2025, 6, 27),
          gameName: 'Assetto Corsa Competizione',
          price: 11.99,
          originalPrice: 39.99,
        ),
        SteamPurchase(
          purchaseDate: DateTime(2025, 12, 22),
          gameName: 'Horizon Zero Dawn Remastered',
          price: 9.99,
          originalPrice: 49.99,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final stats = SteamStatistics(testPurchases);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam Stats'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: isWide ? 3 : 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 2.4 : 4,
                  children: [
                    StatCard(
                      title: 'Spiele',
                      value: stats.totalGames.toString(),
                    ),
                    StatCard(
                      title: 'Gesamtausgaben',
                      value: '${stats.totalSpent.toStringAsFixed(2)} €',
                    ),
                    StatCard(
                      title: 'Ø Rabatt',
                      value: stats.averageDiscount == null
                          ? '-'
                          : '${(stats.averageDiscount! * 100).toStringAsFixed(1)} %',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Käufe',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: testPurchases.length,
                    itemBuilder: (context, index) {
                      final purchase = testPurchases[index];

                      return Card(
                        child: ListTile(
                          title: Text(purchase.gameName),
                          subtitle: Text(
                            '${purchase.purchaseDate.day}.${purchase.purchaseDate.month}.${purchase.purchaseDate.year}',
                          ),
                          trailing: Text(
                            '${purchase.price.toStringAsFixed(2)} €',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}