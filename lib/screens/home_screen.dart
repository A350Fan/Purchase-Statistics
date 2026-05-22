import 'package:flutter/material.dart';

import '../data/steam_purchase_repository.dart';
import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';
import '../widgets/stat_card.dart';
import 'add_purchase_screen.dart';
import 'statistics_tab.dart';

enum PurchaseSortOption {
  dateNewestFirst,
  dateOldestFirst,
  priceHighestFirst,
  priceLowestFirst,
  nameAZ,
  nameZA,
  discountHighestFirst,
  discountLowestFirst,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SteamPurchaseRepository _repository = SteamPurchaseRepository();

  List<SteamPurchase> _purchases = [];
  bool _isLoading = true;
  PurchaseSortOption _sortOption = PurchaseSortOption.dateNewestFirst;

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

  List<SteamPurchase> _getSortedPurchases() {
    final sortedPurchases = [..._purchases];

    sortedPurchases.sort((a, b) {
      switch (_sortOption) {
        case PurchaseSortOption.dateNewestFirst:
          return b.purchaseDate.compareTo(a.purchaseDate);

        case PurchaseSortOption.dateOldestFirst:
          return a.purchaseDate.compareTo(b.purchaseDate);

        case PurchaseSortOption.priceHighestFirst:
          return b.price.compareTo(a.price);

        case PurchaseSortOption.priceLowestFirst:
          return a.price.compareTo(b.price);

        case PurchaseSortOption.nameAZ:
          return a.gameName.toLowerCase().compareTo(b.gameName.toLowerCase());

        case PurchaseSortOption.nameZA:
          return b.gameName.toLowerCase().compareTo(a.gameName.toLowerCase());

        case PurchaseSortOption.discountHighestFirst:
          final discountA = a.discount ?? -1;
          final discountB = b.discount ?? -1;
          return discountB.compareTo(discountA);

        case PurchaseSortOption.discountLowestFirst:
          final discountA = a.discount ?? 101;
          final discountB = b.discount ?? 101;
          return discountA.compareTo(discountB);
      }
    });

    return sortedPurchases;
  }

  String _getSortLabel(PurchaseSortOption option) {
    switch (option) {
      case PurchaseSortOption.dateNewestFirst:
        return 'Datum: neueste zuerst';

      case PurchaseSortOption.dateOldestFirst:
        return 'Datum: älteste zuerst';

      case PurchaseSortOption.priceHighestFirst:
        return 'Preis: höchste zuerst';

      case PurchaseSortOption.priceLowestFirst:
        return 'Preis: niedrigste zuerst';

      case PurchaseSortOption.nameAZ:
        return 'Name: A-Z';

      case PurchaseSortOption.nameZA:
        return 'Name: Z-A';

      case PurchaseSortOption.discountHighestFirst:
        return 'Rabatt: höchste zuerst';

      case PurchaseSortOption.discountLowestFirst:
        return 'Rabatt: niedrigste zuerst';
    }
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
    final sortedPurchases = _getSortedPurchases();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Steam Stats'),

          // Die TabBar hängt direkt unter der AppBar.
          // Tab 1 bleibt deine bisherige Übersicht.
          // Tab 2 bekommt die neue grafische Statistik.
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Übersicht'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Statistik'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddPurchaseScreen,
          icon: const Icon(Icons.add),
          label: const Text('Kauf'),
        ),

        // Loading bleibt global, damit beide Tabs erst angezeigt werden,
        // wenn die Käufe aus der Datenbank geladen wurden.
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // TAB 1: Deine bisherige Startseite.
                  // Hier bleibt Dashboard + sortierbare Kaufliste komplett erhalten.
                  Padding(
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
                                  value:
                                      '${stats.totalSpent.toStringAsFixed(2)} €',
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
                            Row(
                              children: [
                                Text(
                                  'Käufe',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const Spacer(),
                                DropdownButton<PurchaseSortOption>(
                                  value: _sortOption,
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _sortOption = value;
                                    });
                                  },
                                  items: PurchaseSortOption.values.map((
                                    option,
                                  ) {
                                    return DropdownMenuItem(
                                      value: option,
                                      child: Text(_getSortLabel(option)),
                                    );
                                  }).toList(),
                                ),
                              ],
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
                                      itemCount: sortedPurchases.length,
                                      itemBuilder: (context, index) {
                                        final purchase = sortedPurchases[index];

                                        final discountText =
                                            purchase.discount == null
                                            ? null
                                            : '${(purchase.discount! * 100).toStringAsFixed(1)} % Rabatt';

                                        return Card(
                                          child: ListTile(
                                            onTap: () =>
                                                _openEditPurchaseScreen(
                                                  purchase,
                                                ),
                                            title: Text(purchase.gameName),
                                            subtitle: Text(
                                              discountText == null
                                                  ? _formatDate(
                                                      purchase.purchaseDate,
                                                    )
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
                                                  icon: const Icon(
                                                    Icons.delete,
                                                  ),
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

                  // TAB 2: Neue grafische Statistik.
                  // Dieser Screen bekommt dieselben Käufe wie die Übersicht,
                  // berechnet daraus aber eigene Balken/Charts.
                  StatisticsTab(purchases: _purchases),
                ],
              ),
      ),
    );
  }
}
