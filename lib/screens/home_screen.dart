import 'package:flutter/material.dart';

import '../data/steam_purchase_repository.dart';
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
  final SteamPurchaseRepository _repository = SteamPurchaseRepository();

  List<SteamPurchase> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    final purchases = await _repository.getAllPurchases();

    if (!mounted) {
      return;
    }

    setState(() {
      _purchases = purchases;
      _isLoading = false;
    });
  }

  Future<void> _openAddPurchaseScreen() async {
    final newPurchase = await Navigator.of(context).push<SteamPurchase>(
      MaterialPageRoute(builder: (context) => const AddPurchaseScreen()),
    );

    if (newPurchase == null) {
      return;
    }

    await _repository.addPurchase(newPurchase);
    await _loadPurchases();
  }

  Future<void> _openEditPurchaseScreen(SteamPurchase purchase) async {
    final editedPurchase = await Navigator.of(context).push<SteamPurchase>(
      MaterialPageRoute(
        builder: (context) => AddPurchaseScreen(initialPurchase: purchase),
      ),
    );

    if (editedPurchase == null) {
      return;
    }

    await _repository.updatePurchase(editedPurchase);
    await _loadPurchases();
  }

  Future<void> _confirmDeletePurchase(SteamPurchase purchase) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kauf löschen?'),
          content: Text('Möchtest du "${purchase.gameName}" wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _deletePurchase(purchase);
  }

  Future<void> _deletePurchase(SteamPurchase purchase) async {
    if (purchase.id == null) {
      return;
    }

    await _repository.deletePurchase(purchase.id!);
    await _loadPurchases();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${purchase.gameName}" wurde gelöscht.')),
    );
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
      appBar: AppBar(title: const Text('Steam Stats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPurchaseScreen,
        icon: const Icon(Icons.add),
        label: const Text('Kauf'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
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
                        child: _purchases.isEmpty
                            ? const Center(
                                child: Text(
                                  'Noch keine Käufe vorhanden. Füge deinen ersten Steam-Kauf hinzu.',
                                ),
                              )
                            : ListView.builder(
                                itemCount: _purchases.length,
                                itemBuilder: (context, index) {
                                  final purchase = _purchases[index];

                                  final discountText = purchase.discount == null
                                      ? null
                                      : '${(purchase.discount! * 100).toStringAsFixed(1)} % Rabatt';

                                  return Card(
                                    child: ListTile(
                                      onTap: () =>
                                          _openEditPurchaseScreen(purchase),
                                      title: Text(purchase.gameName),
                                      subtitle: Text(
                                        discountText == null
                                            ? _formatDate(purchase.purchaseDate)
                                            : '${_formatDate(purchase.purchaseDate)} · $discountText',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${purchase.price.toStringAsFixed(2)} €',
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Bearbeiten',
                                            onPressed: () =>
                                                _openEditPurchaseScreen(
                                                  purchase,
                                                ),
                                            icon: const Icon(Icons.edit),
                                          ),
                                          IconButton(
                                            tooltip: 'Löschen',
                                            onPressed: () =>
                                                _confirmDeletePurchase(
                                                  purchase,
                                                ),
                                            icon: const Icon(Icons.delete),
                                          ),
                                        ],
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
