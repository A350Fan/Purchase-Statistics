import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/steam_collection_repository.dart';
import '../data/steam_game_metadata_service.dart';
import '../data/steam_purchase_csv.dart';
import '../data/steam_purchase_repository.dart';
import '../l10n/app_strings.dart';
import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';
import '../widgets/stat_card.dart';
import 'add_purchase_screen.dart';
import 'charts_tab.dart';
import 'collections_tab.dart';
import 'settings_screen.dart';
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
  final SteamPurchaseRepository? repository;
  final SteamCollectionRepository? collectionRepository;
  final SteamGameMetadataService? metadataService;

  const HomeScreen({
    super.key,
    this.repository,
    this.collectionRepository,
    this.metadataService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final SteamPurchaseRepository _repository;
  late final SteamCollectionRepository _collectionRepository;
  late final SteamGameMetadataService _metadataService;
  late final TabController _tabController;
  final _collectionsTabKey = GlobalKey<CollectionsTabState>();
  final _purchaseSearchController = TextEditingController();

  List<SteamPurchase> _purchases = [];
  bool _isLoading = true;
  bool _isCsvOperationRunning = false;
  int _selectedTabIndex = 0;
  PurchaseSortOption _sortOption = PurchaseSortOption.dateNewestFirst;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SteamPurchaseRepository();
    _collectionRepository =
        widget.collectionRepository ?? SteamCollectionRepository();
    _metadataService = widget.metadataService ?? SteamGameMetadataService();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_handleTabSelectionChanged);
    _loadPurchases();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelectionChanged);
    _tabController.dispose();
    _purchaseSearchController.dispose();
    super.dispose();
  }

  void _handleTabSelectionChanged() {
    if (_selectedTabIndex == _tabController.index) {
      return;
    }

    setState(() {
      _selectedTabIndex = _tabController.index;
    });
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

  List<SteamPurchase> _getSortedPurchases(SteamStatistics stats) {
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
          final pricePerHourA =
              stats.pricePerHourForPurchase(a) ?? double.infinity;
          final pricePerHourB =
              stats.pricePerHourForPurchase(b) ?? double.infinity;
          return pricePerHourA.compareTo(pricePerHourB);

        case PurchaseSortOption.pricePerHourHighestFirst:
          final pricePerHourA = stats.pricePerHourForPurchase(a) ?? -1;
          final pricePerHourB = stats.pricePerHourForPurchase(b) ?? -1;
          return pricePerHourB.compareTo(pricePerHourA);
      }
    });

    return sortedPurchases;
  }

  List<SteamPurchase> _getFilteredPurchases(
    List<SteamPurchase> purchases,
    AppStrings strings,
  ) {
    final query = _normalizeSearchText(_purchaseSearchController.text);

    if (query.isEmpty) {
      return purchases;
    }

    return purchases.where((purchase) {
      final gameStatus = purchase.purchaseType == SteamPurchaseType.game
          ? purchase.gameStatus
          : null;
      final gameStatusText = gameStatus == null
          ? ''
          : strings.gameStatusLabel(gameStatus);

      return _normalizeSearchText(purchase.displayName).contains(query) ||
          _normalizeSearchText(purchase.gameName).contains(query) ||
          _normalizeSearchText(purchase.dlcName ?? '').contains(query) ||
          _normalizeSearchText(gameStatusText).contains(query);
    }).toList();
  }

  String _normalizeSearchText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _getSortLabel(
    PurchaseSortOption option,
    AppStrings strings,
    AppCurrency currency,
  ) {
    return strings.sortLabel(option.name, currency.symbol);
  }

  String _getPurchaseTypeLabel(SteamPurchaseType type, AppStrings strings) {
    return switch (type) {
      SteamPurchaseType.game => strings.game,
      SteamPurchaseType.dlc => strings.dlc,
    };
  }

  Future<void> _openAddPurchaseScreen() async {
    final result = await Navigator.of(context).push<PurchaseEditorResult>(
      MaterialPageRoute(
        builder: (context) => AddPurchaseScreen(
          existingPurchases: _purchases,
          collectionRepository: _collectionRepository,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final savedPurchase = await _repository.addPurchase(result.purchase);

    if (savedPurchase.id != null && result.collectionIds != null) {
      await _collectionRepository.replaceCollectionsForPurchase(
        purchaseId: savedPurchase.id!,
        collectionIds: result.collectionIds!,
      );
      await _collectionsTabKey.currentState?.refresh();
    }

    await _refreshMetadataForPurchase(savedPurchase);
    await _loadPurchases();
  }

  void _openCreateCollectionDialog() {
    final collectionsTabState = _collectionsTabKey.currentState;

    if (collectionsTabState != null) {
      collectionsTabState.openCreateCollectionDialog();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _collectionsTabKey.currentState?.openCreateCollectionDialog();
    });
  }

  Future<void> _openEditPurchaseScreen(SteamPurchase purchase) async {
    final result = await Navigator.of(context).push<PurchaseEditorResult>(
      MaterialPageRoute(
        builder: (context) => AddPurchaseScreen(
          initialPurchase: purchase,
          existingPurchases: _purchases,
          collectionRepository: _collectionRepository,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    await _repository.updatePurchase(result.purchase);

    if (purchase.id != null && result.collectionIds != null) {
      await _collectionRepository.replaceCollectionsForPurchase(
        purchaseId: purchase.id!,
        collectionIds: result.collectionIds!,
      );
      await _collectionsTabKey.currentState?.refresh();
    }

    await _refreshMetadataForPurchase(result.purchase);
    await _loadPurchases();
  }

  Future<void> _refreshMetadataForPurchase(SteamPurchase purchase) async {
    if (purchase.steamAppId == null) {
      return;
    }

    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;

    try {
      await _metadataService.refreshMetadataForPurchase(
        purchase: purchase,
        language: _steamLanguage(strings),
        countryCode: _steamCountryCode(currency),
      );
    } catch (_) {
      // Metadata refresh must not block saving a purchase.
    }
  }

  void _openSettingsScreen() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _importPurchasesFromCsv() async {
    if (_isCsvOperationRunning) {
      return;
    }

    final strings = AppStrings.of(context);

    setState(() {
      _isCsvOperationRunning = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: strings.importCsv,
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
        _showSnackBar(strings.csvEmpty);
        return;
      }

      final importedCount = await _repository.addPurchases(purchases);
      await _loadPurchases();
      _showSnackBar(strings.importedPurchases(importedCount));
    } on SteamPurchaseCsvException catch (error) {
      _showSnackBar(strings.csvImportFailed(error));
    } catch (error) {
      _showSnackBar(strings.csvImportFailed(error));
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

    final strings = AppStrings.of(context);

    setState(() {
      _isCsvOperationRunning = true;
    });

    try {
      final sortedPurchases = _getSortedPurchases(SteamStatistics(_purchases));
      final csv = SteamPurchaseCsv.encode(sortedPurchases);
      final fileName = 'steam_purchases_${_formatFileDate(DateTime.now())}.csv';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: strings.exportCsv,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
        lockParentWindow: true,
      );

      if (path == null) {
        return;
      }

      _showSnackBar(strings.exportedPurchases(sortedPurchases.length));
    } catch (error) {
      _showSnackBar(strings.csvExportFailed(error));
    } finally {
      if (mounted) {
        setState(() {
          _isCsvOperationRunning = false;
        });
      }
    }
  }

  Future<void> _confirmDeletePurchase(SteamPurchase purchase) async {
    final strings = AppStrings.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.deletePurchaseTitle),
          content: Text(strings.deletePurchaseMessage(purchase.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.delete),
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

    final strings = AppStrings.of(context);

    await _repository.deletePurchase(purchase.id!);
    await _loadPurchases();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.deletedPurchase(purchase.displayName))),
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

  String _formatPricePerHour(double value, AppCurrency currency) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}/h';
  }

  String _formatCurrency(double value, AppCurrency currency) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}';
  }

  String _steamLanguage(AppStrings strings) {
    return strings.isEnglish ? 'english' : 'german';
  }

  String _steamCountryCode(AppCurrency currency) {
    return switch (currency) {
      AppCurrency.eur => 'DE',
      AppCurrency.usd => 'US',
      AppCurrency.gbp => 'GB',
      AppCurrency.chf => 'CH',
      AppCurrency.jpy => 'JP',
    };
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

  Widget _buildPurchaseCard(
    SteamPurchase purchase,
    SteamStatistics stats,
    AppCurrency currency,
  ) {
    final strings = AppStrings.of(context);
    final discountText = purchase.discount == null
        ? null
        : '${(purchase.discount! * 100).toStringAsFixed(1)} %';
    final playtimeText = _formatPlaytime(purchase.playtimeHours);
    final pricePerHour = stats.pricePerHourForPurchase(purchase);
    final pricePerHourText = pricePerHour == null
        ? null
        : _formatPricePerHour(pricePerHour, currency);

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
              final titleSection = _buildPurchaseTitleSection(
                purchase,
                strings,
              );
              final dataSection = _buildPurchaseDataSection(
                strings: strings,
                priceText: _formatCurrency(purchase.price, currency),
                discountText: discountText,
                playtimeText: playtimeText,
                pricePerHourText: pricePerHourText,
              );
              final actions = _buildPurchaseActions(purchase, strings);

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

  Widget _buildPurchaseTitleSection(
    SteamPurchase purchase,
    AppStrings strings,
  ) {
    final theme = Theme.of(context);
    final gameStatus = purchase.purchaseType == SteamPurchaseType.game
        ? purchase.gameStatus
        : null;
    final subtitleParts = [
      _getPurchaseTypeLabel(purchase.purchaseType, strings),
      _formatDate(purchase.purchaseDate),
      if (gameStatus != null) strings.gameStatusLabel(gameStatus),
    ];

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
          subtitleParts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseDataSection({
    required AppStrings strings,
    required String priceText,
    required String? discountText,
    required String? playtimeText,
    required String? pricePerHourText,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots = [
          _buildPurchaseDataSlot(strings.price, priceText),
          _buildPurchaseDataSlot(strings.discount, discountText),
          _buildPurchaseDataSlot(strings.playtime, playtimeText),
          _buildPurchaseDataSlot(strings.cost, pricePerHourText),
        ];

        if (constraints.maxWidth < 440) {
          final hasSecondRow = playtimeText != null || pricePerHourText != null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: slots[0]),
                  const SizedBox(width: 8),
                  Expanded(child: slots[1]),
                ],
              ),
              if (hasSecondRow) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: slots[2]),
                    const SizedBox(width: 8),
                    Expanded(child: slots[3]),
                  ],
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < slots.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: slots[index]),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPurchaseDataSlot(String label, String? value) {
    if (value == null) {
      return const SizedBox(height: 64);
    }

    return _buildPurchaseDataItem(label, value);
  }

  Widget _buildPurchaseDataItem(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
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

  Widget _buildPurchaseActions(SteamPurchase purchase, AppStrings strings) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: strings.edit,
          onPressed: () => _openEditPurchaseScreen(purchase),
          icon: const Icon(Icons.edit),
        ),
        IconButton(
          tooltip: strings.delete,
          onPressed: () => _confirmDeletePurchase(purchase),
          icon: const Icon(Icons.delete),
        ),
      ],
    );
  }

  Widget _buildPurchaseListHeader(AppStrings strings, AppCurrency currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              strings.purchases,
              style: Theme.of(context).textTheme.headlineSmall,
            );
            final sortMenu = DropdownButton<PurchaseSortOption>(
              value: _sortOption,
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _sortOption = value;
                });
              },
              items: PurchaseSortOption.values.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(_getSortLabel(option, strings, currency)),
                );
              }).toList(),
            );

            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: sortMenu),
                ],
              );
            }

            return Row(children: [title, const Spacer(), sortMenu]);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _purchaseSearchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: strings.purchaseSearch,
            border: const OutlineInputBorder(),
            suffixIcon: _purchaseSearchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: strings.clearSearch,
                    onPressed: () {
                      setState(() {
                        _purchaseSearchController.clear();
                      });
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(AppStrings strings) {
    if (_selectedTabIndex == 3) {
      return FloatingActionButton.extended(
        onPressed: _openCreateCollectionDialog,
        icon: const Icon(Icons.create_new_folder),
        label: Text(strings.collectionFab),
      );
    }

    return FloatingActionButton.extended(
      onPressed: _openAddPurchaseScreen,
      icon: const Icon(Icons.add),
      label: Text(strings.purchaseFab),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final stats = SteamStatistics(_purchases);
    final sortedPurchases = _getSortedPurchases(stats);
    final filteredPurchases = _getFilteredPurchases(sortedPurchases, strings);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            tooltip: strings.importCsv,
            onPressed: _isCsvOperationRunning ? null : _importPurchasesFromCsv,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: strings.exportCsv,
            onPressed: _isCsvOperationRunning ? null : _exportPurchasesToCsv,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: strings.openSettings,
            onPressed: _openSettingsScreen,
            icon: const Icon(Icons.settings),
          ),
        ],

        // Die TabBar hängt direkt unter der AppBar.
        // Übersicht, Zahlen, Diagramme und Kollektionen bleiben getrennt.
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard), text: strings.overviewTab),
            Tab(icon: const Icon(Icons.bar_chart), text: strings.statisticsTab),
            Tab(icon: const Icon(Icons.show_chart), text: strings.chartsTab),
            Tab(icon: const Icon(Icons.folder), text: strings.collectionsTab),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(strings),

      // Loading bleibt global, damit die Tabs erst angezeigt werden,
      // wenn die Käufe aus der Datenbank geladen wurden.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
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
                              strings.dashboard,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
                                title: strings.purchases,
                                value: stats.totalPurchases.toString(),
                              ),
                              StatCard(
                                title: strings.games,
                                value: stats.totalGames.toString(),
                              ),
                              StatCard(
                                title: strings.dlcs,
                                value: stats.totalDlcs.toString(),
                              ),
                              StatCard(
                                title: strings.totalSpent,
                                value: _formatCurrency(
                                  stats.totalSpent,
                                  currency,
                                ),
                              ),
                              StatCard(
                                title: strings.averageDiscount,
                                value: stats.averageDiscount == null
                                    ? '-'
                                    : '${(stats.averageDiscount! * 100).toStringAsFixed(1)} %',
                              ),
                              StatCard(
                                title: strings.playtime,
                                value: _formatTotalPlaytime(
                                  stats.totalPlaytimeHours,
                                ),
                              ),
                              StatCard(
                                title: strings.averagePricePerHour(
                                  currency.symbol,
                                ),
                                value: stats.pricePerHour == null
                                    ? '-'
                                    : _formatPricePerHour(
                                        stats.pricePerHour!,
                                        currency,
                                      ),
                              ),
                            ]),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          SliverToBoxAdapter(
                            child: _buildPurchaseListHeader(strings, currency),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          if (_purchases.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: Text(strings.noPurchases)),
                            )
                          else if (filteredPurchases.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(strings.noMatchingPurchases),
                              ),
                            )
                          else
                            SliverList.builder(
                              itemCount: filteredPurchases.length,
                              itemBuilder: (context, index) {
                                final purchase = filteredPurchases[index];
                                return _buildPurchaseCard(
                                  purchase,
                                  stats,
                                  currency,
                                );
                              },
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 88)),
                        ],
                      );
                    },
                  ),
                ),

                // TAB 2: Statistik in Zahlen.
                StatisticsTab(purchases: _purchases),

                // TAB 3: Statistik als Diagramme.
                ChartsTab(purchases: _purchases),

                // TAB 4: Manuelle Kollektionen als stabile Grundlage.
                CollectionsTab(
                  key: _collectionsTabKey,
                  repository: _collectionRepository,
                  purchases: _purchases,
                ),
              ],
            ),
    );
  }
}
