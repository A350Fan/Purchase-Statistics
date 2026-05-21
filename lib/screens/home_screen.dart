import 'package:flutter/material.dart';

import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';
import '../widgets/stat_card.dart';
import 'add_purchase_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<SteamPurchase> _purchases = [
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

  Future<void> _openAddPurchaseScreen() async {
    final newPurchase = await Navigator.of(context).push<SteamPurchase>(
      MaterialPageRoute(
        builder: (context) => const AddPurchaseScreen(),
      ),
    );

    if (newPurchase == null) {
      return;
    }

    setState(() {
      _purchases.add(newPurchase);
      _purchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final stats = SteamStatistics(_purchases);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steam Stats'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPurchaseScreen,
        icon: const Icon(Icons.add),
        label: const Text('Kauf'),
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
                    itemCount: _purchases.length,
                    itemBuilder: (context, index) {
                      final purchase = _purchases[index];

                      final discountText = purchase.discount == null
                          ? null
                          : '${(purchase.discount! * 100).toStringAsFixed(1)} % Rabatt';

                      return Card(
                        child: ListTile(
                          title: Text(purchase.gameName),
                          subtitle: Text(
                            discountText == null
                                ? _formatDate(purchase.purchaseDate)
                                : '${_formatDate(purchase.purchaseDate)} · $discountText',
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