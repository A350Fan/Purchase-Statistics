import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/steam_purchase_csv.dart';
import '../data/steam_purchase_repository.dart';
import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';
import '../widgets/stat_card.dart';
import 'add_purchase_screen.dart';
import 'charts_tab.dart';
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
  playtimeHighestFirst,
  playtimeLowestFirst,
  pricePerHourLowestFirst,
  pricePerHourHighestFirst,
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
  bool _isCsvOperationRunning = false;
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
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );

        case PurchaseSortOption.nameZA:
          return b.displayName.toLowerCase().compareTo(
            a.displayName.toLowerCase(),
          );

        case PurchaseSortOption.discountHighestFirst:
          final discountA = a.discount ?? -1;
          final discountB = b.discount ?? -1;
          return discountB.compareTo(discountA);

        case PurchaseSortOption.discountLowestFirst:
          final discountA = a.discount ?? 101;
          final discountB = b.discount ?? 101;
          return discountA.compareTo(discountB);

        case PurchaseSortOption.playtimeHighestFirst:
          final playtimeA = a.playtimeHours ?? -1;
          final playtimeB = b.playtimeHours ?? -1;
          return playtimeB.compareTo(playtimeA);

        case PurchaseSortOption.playtimeLowestFirst:
          final playtimeA = (a.playtimeHours ?? 0) > 0
              ? a.playtimeHours!
              : double.infinity;
          final playtimeB = (b.playtimeHours ?? 0) > 0
              ? b.playtimeHours!
              : double.infinity;
          return playtimeA.compareTo(playtimeB);

        case PurchaseSortOption.pricePerHourLowestFirst:
          final pricePerHourA = a.pricePerHour ?? double.infinity;
          final pricePerHourB = b.pricePerHour ?? double.infinity;
          return pricePerHourA.compareTo(pricePerHourB);

        case PurchaseSortOption.pricePerHourHighestFirst:
          final pricePerHourA = a.pricePerHour ?? -1;
          final pricePerHourB = b.pricePerHour ?? -1;
          return pricePerHourB.compareTo(pricePerHourA);
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

      case PurchaseSortOption.playtimeHighestFirst:
        return 'Spielzeit: höchste zuerst';

      case PurchaseSortOption.playtimeLowestFirst:
        return 'Spielzeit: niedrigste zuerst';

      case PurchaseSortOption.pricePerHourLowestFirst:
        return '€/h: niedrigste zuerst';

      case PurchaseSortOption.pricePerHourHighestFirst:
        return '€/h: höchste zuerst';
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

  Future<void> _importPurchasesFromCsv() async {
    if (_isCsvOperationRunning) {
      return;
    }

    setState(() {
      _isCsvOperationRunning = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Steam-Käufe importieren',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final csv = await _readPickedCsvFile(result.files.single);
      final purchases = SteamPurchaseCsv.decode(csv);

      if (purchases.isEmpty) {
        _showSnackBar('Die CSV enthält keine Käufe.');
        return;
      }

      final importedCount = await _repository.addPurchases(purchases);
      await _loadPurchases();
      _showSnackBar(
        importedCount == 1
            ? '1 Kauf wurde importiert.'
            : '$importedCount Käufe wurden importiert.',
      );
    } on SteamPurchaseCsvException catch (error) {
      _showSnackBar('CSV konnte nicht importiert werden: $error');
    } catch (error) {
      _showSnackBar('CSV konnte nicht importiert werden: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCsvOperationRunning = false;
        });
      }
    }
  }

  Future<String> _readPickedCsvFile(PlatformFile file) async {
    final bytes = file.bytes;

    if (bytes != null) {
      return utf8.decode(bytes, allowMalformed: true);
    }

    final path = file.path;

    if (path == null) {
      throw const SteamPurchaseCsvException(
        'Die ausgewählte Datei konnte nicht gelesen werden.',
      );
    }

    return File(path).readAsString();
  }

  Future<void> _exportPurchasesToCsv() async {
    if (_isCsvOperationRunning) {
      return;
    }

    setState(() {
      _isCsvOperationRunning = true;
    });

    try {
      final sortedPurchases = _getSortedPurchases();
      final csv = SteamPurchaseCsv.encode(sortedPurchases);
      final fileName = 'steam_purchases_${_formatFileDate(DateTime.now())}.csv';
      final path = await FilePicker.saveFile(
        dialogTitle: 'Steam-Käufe exportieren',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
        lockParentWindow: true,
      );

      if (path == null) {
        return;
      }

      _showSnackBar(
        sortedPurchases.length == 1
            ? '1 Kauf wurde exportiert.'
            : '${sortedPurchases.length} Käufe wurden exportiert.',
      );
    } catch (error) {
      _showSnackBar('CSV konnte nicht exportiert werden: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCsvOperationRunning = false;
        });
      }
    }
  }

  Future<void> _confirmDeletePurchase(SteamPurchase purchase) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kauf löschen?'),
          content: Text(
            'Möchtest du "${purchase.displayName}" wirklich löschen?',
          ),
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
      SnackBar(content: Text('"${purchase.displayName}" wurde gelöscht.')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _formatFileDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String? _formatPlaytime(double? hours) {
    if (hours == null || hours <= 0) {
      return null;
    }

    return '${_formatDecimal(hours)} h';
  }

  String _formatTotalPlaytime(double hours) {
    if (hours <= 0) {
      return '-';
    }

    return '${_formatDecimal(hours)} h';
  }

  String _formatPricePerHour(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €/h';
  }

  String _formatCurrency(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String _formatDecimal(double value) {
    final hasFraction = value != value.roundToDouble();

    return value.toStringAsFixed(hasFraction ? 1 : 0).replaceAll('.', ',');
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildPurchaseCard(SteamPurchase purchase) {
    final discountText = purchase.discount == null
        ? null
        : '${(purchase.discount! * 100).toStringAsFixed(1)} %';
    final playtimeText = _formatPlaytime(purchase.playtimeHours);
    final pricePerHourText = purchase.pricePerHour == null
        ? null
        : _formatPricePerHour(purchase.pricePerHour!);

    final dataItems = [
      _buildPurchaseDataItem('Preis', _formatCurrency(purchase.price)),
      if (discountText != null) _buildPurchaseDataItem('Rabatt', discountText),
      if (playtimeText != null)
        _buildPurchaseDataItem('Spielzeit', playtimeText),
      if (pricePerHourText != null)
        _buildPurchaseDataItem('Kosten', pricePerHourText),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _openEditPurchaseScreen(purchase),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              final titleSection = _buildPurchaseTitleSection(purchase);
              final dataSection = _buildPurchaseDataSection(
                dataItems,
                alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
              );
              final actions = _buildPurchaseActions(purchase);

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: titleSection),
                        const SizedBox(width: 8),
                        actions,
                      ],
                    ),
                    const SizedBox(height: 12),
                    dataSection,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: titleSection),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: dataSection),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseTitleSection(SteamPurchase purchase) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          purchase.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${purchase.purchaseType.label} · ${_formatDate(purchase.purchaseDate)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseDataSection(
    List<Widget> items, {
    required WrapAlignment alignment,
  }) {
    return Wrap(
      alignment: alignment,
      runAlignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }

  Widget _buildPurchaseDataItem(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withAlpha(18),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseActions(SteamPurchase purchase) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Bearbeiten',
          onPressed: () => _openEditPurchaseScreen(purchase),
          icon: const Icon(Icons.edit),
        ),
        IconButton(
          tooltip: 'Löschen',
          onPressed: () => _confirmDeletePurchase(purchase),
          icon: const Icon(Icons.delete),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = SteamStatistics(_purchases);
    final sortedPurchases = _getSortedPurchases();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Steam Stats'),
          actions: [
            IconButton(
              tooltip: 'CSV importieren',
              onPressed: _isCsvOperationRunning
                  ? null
                  : _importPurchasesFromCsv,
              icon: const Icon(Icons.upload_file),
            ),
            IconButton(
              tooltip: 'CSV exportieren',
              onPressed: _isCsvOperationRunning ? null : _exportPurchasesToCsv,
              icon: const Icon(Icons.download),
            ),
          ],

          // Die TabBar hängt direkt unter der AppBar.
          // Übersicht, Zahlentabellen und Diagramme bleiben getrennt.
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Übersicht'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Statistik'),
              Tab(icon: Icon(Icons.show_chart), text: 'Diagramme'),
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
                        final dashboardColumnCount = constraints.maxWidth > 1200
                            ? 5
                            : isWide
                            ? 3
                            : 2;

                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Text(
                                'Dashboard',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 16),
                            ),
                            SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: dashboardColumnCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: isWide ? 2.4 : 1.9,
                                  ),
                              delegate: SliverChildListDelegate.fixed([
                                StatCard(
                                  title: 'Käufe',
                                  value: stats.totalPurchases.toString(),
                                ),
                                StatCard(
                                  title: 'Spiele',
                                  value: stats.totalGames.toString(),
                                ),
                                StatCard(
                                  title: 'DLCs',
                                  value: stats.totalDlcs.toString(),
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
                                StatCard(
                                  title: 'Spielzeit',
                                  value: _formatTotalPlaytime(
                                    stats.totalPlaytimeHours,
                                  ),
                                ),
                                StatCard(
                                  title: 'Ø €/h',
                                  value: stats.pricePerHour == null
                                      ? '-'
                                      : _formatPricePerHour(
                                          stats.pricePerHour!,
                                        ),
                                ),
                              ]),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 24),
                            ),
                            SliverToBoxAdapter(
                              child: Row(
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
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 8),
                            ),
                            if (_purchases.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    'Noch keine Käufe vorhanden. Füge deinen ersten Steam-Kauf hinzu.',
                                  ),
                                ),
                              )
                            else
                              SliverList.builder(
                                itemCount: sortedPurchases.length,
                                itemBuilder: (context, index) {
                                  final purchase = sortedPurchases[index];
                                  return _buildPurchaseCard(purchase);
                                },
                              ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 88),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // TAB 2: Statistik in Zahlen.
                  StatisticsTab(purchases: _purchases),

                  // TAB 3: Statistik als Diagramme.
                  ChartsTab(purchases: _purchases),
                ],
              ),
      ),
    );
  }
}
