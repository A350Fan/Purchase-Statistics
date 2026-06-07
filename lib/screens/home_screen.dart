import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/steam_collection_repository.dart';
import '../data/steam_app_linking_service.dart';
import '../data/steam_game_length_estimate_repository.dart';
import '../data/steam_game_metadata_service.dart';
import '../data/steam_goal_repository.dart';
import '../data/steam_playtime_sync_service.dart';
import '../data/steam_purchase_csv.dart';
import '../data/steam_purchase_repository.dart';
import '../l10n/app_strings.dart';
import '../logic/steam_insights.dart';
import '../logic/steam_statistics.dart';
import '../models/steam_collection.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';
import '../widgets/stat_card.dart';
import 'add_purchase_screen.dart';
import 'charts_tab.dart';
import 'collections_tab.dart';
import 'goals_tab.dart';
import 'purchase_filters.dart';
import 'settings_screen.dart';
import 'smart_insights_tab.dart';
import 'statistics_tab.dart';

/// Sortiermoeglichkeiten fuer die Kaufuebersicht.
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

/// Aktionen aus App-Bar- und Automatisierungsmenues.
enum _HomeAction {
  autoLinkSteamApps,
  syncSteamPlaytime,
  refreshMissingMetadata,
  refreshAllMetadata,
  createSmartCollections,
  importCsv,
  importLengthEstimatesCsv,
  exportCsv,
  exportLengthEstimatesCsv,
  settings,
}

enum _PurchaseCardAction { edit, delete }

/// Hauptscreen der App.
///
/// Er haelt die geladene Kauf-Liste, koordiniert Repositories/Services und
/// verteilt die Daten an Dashboard, Statistik, Diagramme, Insights, Ziele und
/// Kollektionen.
class HomeScreen extends StatefulWidget {
  final SteamPurchaseRepository? repository;
  final SteamCollectionRepository? collectionRepository;
  final SteamGameLengthEstimateRepository? lengthEstimateRepository;
  final SteamGameMetadataService? metadataService;
  final SteamAppLinkingService? appLinkingService;
  final SteamPlaytimeSyncService? playtimeSyncService;
  final SteamGoalStore? goalStore;

  const HomeScreen({
    super.key,
    this.repository,
    this.collectionRepository,
    this.lengthEstimateRepository,
    this.metadataService,
    this.appLinkingService,
    this.playtimeSyncService,
    this.goalStore,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Layout-Konstanten fuer die responsive Kaufuebersicht.
  static final RegExp _searchWhitespacePattern = RegExp(r'\s+');
  static const double _overviewMaxContentWidth = 1240;
  static const double _purchaseTablePriceColumnWidth = 120;
  static const double _purchaseTableDiscountColumnWidth = 104;
  static const double _purchaseTablePlaytimeColumnWidth = 112;
  static const double _purchaseTableCostColumnWidth = 128;
  static const double _purchaseTableActionsColumnWidth = 96;
  static const int _backlogPrioritySnoozeDays = 14;

  late final SteamPurchaseRepository _repository;
  late final SteamCollectionRepository _collectionRepository;
  late final SteamGameLengthEstimateRepository _lengthEstimateRepository;
  late final SteamGameMetadataService _metadataService;
  late final SteamAppLinkingService _appLinkingService;
  late final SteamPlaytimeSyncService _playtimeSyncService;
  late final SteamGoalStore _goalStore;
  late final TabController _tabController;
  late final bool _ownsMetadataService;
  late final bool _ownsAppLinkingService;
  late final bool _ownsPlaytimeSyncService;
  final _collectionsTabKey = GlobalKey<CollectionsTabState>();
  final _purchaseSearchController = TextEditingController();

  // Kaufdaten plus Caches fuer teurere abgeleitete Listen/Werte. Caches werden
  // invalidiert, sobald Kaeufe, Sortierung, Suche, Filter oder Locale wechseln.
  List<SteamPurchase> _purchases = [];
  SteamStatistics? _cachedStatistics;
  DateTime? _cachedStatisticsDate;
  PurchaseSortOption? _cachedSortOption;
  List<SteamPurchase>? _cachedSortedPurchases;
  List<SteamPurchase>? _cachedFilteredSource;
  List<SteamPurchase>? _cachedFilteredPurchases;
  String? _cachedFilterQuery;
  PurchaseFilters? _cachedFilterState;
  Locale? _cachedFilterLocale;
  List<int>? _cachedPurchaseYears;
  bool _isLoading = true;
  bool _isCsvOperationRunning = false;
  bool _isAutomationRunning = false;
  int _selectedTabIndex = 0;
  PurchaseSortOption _sortOption = PurchaseSortOption.dateNewestFirst;
  PurchaseFilters _purchaseFilters = const PurchaseFilters();

  @override
  void initState() {
    super.initState();
    // Repositories/Services koennen von Tests injiziert werden. Wenn der
    // HomeScreen sie selbst erstellt, ist er auch fuer `dispose` verantwortlich.
    _repository = widget.repository ?? SteamPurchaseRepository();
    _collectionRepository =
        widget.collectionRepository ?? SteamCollectionRepository();
    _lengthEstimateRepository =
        widget.lengthEstimateRepository ?? SteamGameLengthEstimateRepository();
    _ownsMetadataService = widget.metadataService == null;
    _ownsAppLinkingService = widget.appLinkingService == null;
    _ownsPlaytimeSyncService = widget.playtimeSyncService == null;
    _metadataService = widget.metadataService ?? SteamGameMetadataService();
    _appLinkingService = widget.appLinkingService ?? SteamAppLinkingService();
    _playtimeSyncService =
        widget.playtimeSyncService ??
        SteamPlaytimeSyncService(repository: _repository);
    _goalStore = widget.goalStore ?? SteamGoalRepository();
    _tabController = TabController(length: 6, vsync: this)
      ..addListener(_handleTabSelectionChanged);
    _loadPurchases();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelectionChanged);
    _tabController.dispose();
    _purchaseSearchController.dispose();
    if (_ownsMetadataService) {
      _metadataService.dispose();
    }
    if (_ownsAppLinkingService) {
      _appLinkingService.dispose();
    }
    if (_ownsPlaytimeSyncService) {
      _playtimeSyncService.dispose();
    }
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
    // Zentraler Reload nach Import, Bearbeiten, Loeschen und Automatisierung.
    final purchases = await _repository.getAllPurchases();

    if (!mounted) {
      return;
    }

    setState(() {
      _purchases = List.unmodifiable(purchases);
      _invalidatePurchaseCaches();
      _isLoading = false;
    });
  }

  void _invalidatePurchaseCaches() {
    _cachedStatistics = null;
    _cachedStatisticsDate = null;
    _cachedSortOption = null;
    _cachedSortedPurchases = null;
    _cachedPurchaseYears = null;
    _invalidateFilteredPurchaseCache();
  }

  void _invalidateSortedPurchaseCache() {
    _cachedSortOption = null;
    _cachedSortedPurchases = null;
    _invalidateFilteredPurchaseCache();
  }

  void _invalidateFilteredPurchaseCache() {
    _cachedFilteredSource = null;
    _cachedFilteredPurchases = null;
    _cachedFilterQuery = null;
    _cachedFilterState = null;
    _cachedFilterLocale = null;
  }

  DateTime _today() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  SteamStatistics _getStatistics() {
    // Statistikberechnungen werden pro Tag gecacht, weil Projektionen vom
    // aktuellen Datum abhaengen.
    final today = _today();
    final cachedStatistics = _cachedStatistics;

    if (cachedStatistics != null && _cachedStatisticsDate == today) {
      return cachedStatistics;
    }

    _cachedStatisticsDate = today;
    _cachedStatistics = SteamStatistics(_purchases, currentDate: today);

    return _cachedStatistics!;
  }

  List<SteamPurchase> _getSortedPurchases(SteamStatistics stats) {
    // Sortieren kann haeufig durch Rebuilds ausgeloest werden, deshalb wird das
    // Ergebnis pro Sortieroption gecacht.
    final cachedSortedPurchases = _cachedSortedPurchases;

    if (cachedSortedPurchases != null && _cachedSortOption == _sortOption) {
      return cachedSortedPurchases;
    }

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

    _cachedSortOption = _sortOption;
    _cachedSortedPurchases = List.unmodifiable(sortedPurchases);

    return _cachedSortedPurchases!;
  }

  List<SteamPurchase> _getFilteredPurchases(
    List<SteamPurchase> purchases,
    AppStrings strings,
  ) {
    // Filtercache haengt neben Kauf-Liste und Suchtext auch von der Locale ab,
    // weil einzelne Suchlabels/Statusnamen sprachabhaengig sind.
    final query = _normalizeSearchText(_purchaseSearchController.text);
    final filterLocale = strings.locale;
    final cachedFilteredPurchases = _cachedFilteredPurchases;

    if (cachedFilteredPurchases != null &&
        identical(_cachedFilteredSource, purchases) &&
        _cachedFilterQuery == query &&
        _cachedFilterState == _purchaseFilters &&
        _cachedFilterLocale == filterLocale) {
      return cachedFilteredPurchases;
    }

    final List<SteamPurchase> filteredPurchases =
        query.isEmpty && !_purchaseFilters.hasFilters
        ? purchases
        : List<SteamPurchase>.unmodifiable(
            purchases.where((purchase) {
              if (!_purchaseFilters.matches(purchase)) {
                return false;
              }

              if (query.isEmpty) {
                return true;
              }

              final gameStatus = purchase.purchaseType == SteamPurchaseType.game
                  ? purchase.gameStatus
                  : null;
              final gameStatusText = gameStatus == null
                  ? ''
                  : strings.gameStatusLabel(gameStatus);

              return _normalizeSearchText(
                    purchase.displayName,
                  ).contains(query) ||
                  _normalizeSearchText(purchase.gameName).contains(query) ||
                  _normalizeSearchText(
                    purchase.dlcName ?? '',
                  ).contains(query) ||
                  _normalizeSearchText(gameStatusText).contains(query);
            }),
          );

    _cachedFilteredSource = purchases;
    _cachedFilteredPurchases = filteredPurchases;
    _cachedFilterQuery = query;
    _cachedFilterState = _purchaseFilters;
    _cachedFilterLocale = filterLocale;

    return filteredPurchases;
  }

  String _normalizeSearchText(String value) {
    return value.trim().toLowerCase().replaceAll(_searchWhitespacePattern, ' ');
  }

  String _getSortLabel(
    PurchaseSortOption option,
    AppStrings strings,
    AppCurrency currency,
  ) {
    return strings.sortLabel(option.name, currency.symbol);
  }

  List<int> _getPurchaseYears() {
    final cachedPurchaseYears = _cachedPurchaseYears;

    if (cachedPurchaseYears != null) {
      return cachedPurchaseYears;
    }

    final years = _purchases.map((purchase) => purchase.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    _cachedPurchaseYears = List.unmodifiable(years);

    return _cachedPurchaseYears!;
  }

  Future<void> _openPurchaseFiltersDialog(AppCurrency currency) async {
    final filters = await showDialog<PurchaseFilters>(
      context: context,
      builder: (context) {
        return PurchaseFiltersDialog(
          initialFilters: _purchaseFilters,
          availableYears: _getPurchaseYears(),
          currency: currency,
        );
      },
    );

    if (filters == null) {
      return;
    }

    setState(() {
      _purchaseFilters = filters;
      _invalidateFilteredPurchaseCache();
    });
  }

  void _clearPurchaseFilters() {
    setState(() {
      _purchaseFilters = const PurchaseFilters();
      _invalidateFilteredPurchaseCache();
    });
  }

  List<String> _activeFilterLabels(AppStrings strings, AppCurrency currency) {
    final labels = <String>[];

    switch (_purchaseFilters.purchaseType) {
      case PurchaseTypeFilterOption.all:
        break;
      case PurchaseTypeFilterOption.games:
        labels.add(strings.game);
        break;
      case PurchaseTypeFilterOption.dlcs:
        labels.add(strings.dlc);
        break;
    }

    if (_purchaseFilters.statuses.length == 1) {
      labels.add(
        '${strings.status}: '
        '${strings.gameStatusLabel(_purchaseFilters.statuses.single)}',
      );
    } else if (_purchaseFilters.statuses.length > 1) {
      labels.add(strings.statusFilterCount(_purchaseFilters.statuses.length));
    }

    final year = _purchaseFilters.year;

    if (year != null) {
      labels.add('${strings.year}: $year');
    }

    final minPrice = _purchaseFilters.minPrice;
    final maxPrice = _purchaseFilters.maxPrice;

    if (minPrice != null && maxPrice != null) {
      labels.add(
        '${strings.price}: ${_formatCurrency(minPrice, currency)} - '
        '${_formatCurrency(maxPrice, currency)}',
      );
    } else if (minPrice != null) {
      labels.add('${strings.price}: >= ${_formatCurrency(minPrice, currency)}');
    } else if (maxPrice != null) {
      labels.add('${strings.price}: <= ${_formatCurrency(maxPrice, currency)}');
    }

    switch (_purchaseFilters.playtime) {
      case PurchasePlaytimeFilterOption.all:
        break;
      case PurchasePlaytimeFilterOption.withPlaytime:
        labels.add(strings.withPlaytime);
        break;
      case PurchasePlaytimeFilterOption.withoutPlaytime:
        labels.add(strings.withoutPlaytime);
        break;
    }

    switch (_purchaseFilters.discount) {
      case PurchaseDiscountFilterOption.all:
        break;
      case PurchaseDiscountFilterOption.withDiscount:
        labels.add(strings.withDiscount);
        break;
      case PurchaseDiscountFilterOption.withoutDiscount:
        labels.add(strings.withoutDiscount);
        break;
    }

    return labels;
  }

  String _getPurchaseTypeLabel(SteamPurchaseType type, AppStrings strings) {
    return switch (type) {
      SteamPurchaseType.game => strings.game,
      SteamPurchaseType.dlc => strings.dlc,
    };
  }

  Future<void> _openAddPurchaseScreen() async {
    // Der Editor liefert das fertige Kaufmodell zurueck; gespeichert wird hier,
    // damit HomeScreen die Liste danach zentral neu laden kann.
    final result = await Navigator.of(context).push<PurchaseEditorResult>(
      MaterialPageRoute(
        builder: (context) => AddPurchaseScreen(
          existingPurchases: _purchases,
          collectionRepository: _collectionRepository,
          lengthEstimateRepository: _lengthEstimateRepository,
          metadataService: _metadataService,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final savedPurchase = await _repository.addPurchase(result.purchase);
    await _lengthEstimateRepository.upsertPurchaseEstimate(savedPurchase);

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
    // Beim Bearbeiten werden neben dem Kauf auch manuelle Sammlungszuordnungen
    // aktualisiert.
    final result = await Navigator.of(context).push<PurchaseEditorResult>(
      MaterialPageRoute(
        builder: (context) => AddPurchaseScreen(
          initialPurchase: purchase,
          existingPurchases: _purchases,
          collectionRepository: _collectionRepository,
          lengthEstimateRepository: _lengthEstimateRepository,
          metadataService: _metadataService,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    await _repository.updatePurchase(result.purchase);
    await _lengthEstimateRepository.upsertPurchaseEstimate(result.purchase);

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

  Future<void> _snoozeBacklogPriority(SteamPurchase purchase) async {
    if (purchase.id == null) {
      return;
    }

    final strings = AppStrings.of(context);
    final previousSnoozedUntil = purchase.backlogPrioritySnoozedUntil;
    final snoozedUntil = _today().add(
      const Duration(days: _backlogPrioritySnoozeDays),
    );

    try {
      await _repository.updatePurchase(
        purchase.copyWith(backlogPrioritySnoozedUntil: snoozedUntil),
      );
      await _loadPurchases();
      _showBacklogPrioritySnoozedSnackBar(
        purchase: purchase,
        snoozedUntil: snoozedUntil,
        previousSnoozedUntil: previousSnoozedUntil,
      );
    } catch (error) {
      _showSnackBar(strings.backlogPrioritySnoozeFailed(error));
    }
  }

  void _showBacklogPrioritySnoozedSnackBar({
    required SteamPurchase purchase,
    required DateTime snoozedUntil,
    required DateTime? previousSnoozedUntil,
  }) {
    if (!mounted || purchase.id == null) {
      return;
    }

    final strings = AppStrings.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            strings.backlogPrioritySnoozed(
              purchase.displayName,
              _formatDate(snoozedUntil),
            ),
          ),
          action: SnackBarAction(
            label: strings.undo,
            onPressed: () async {
              await _restoreBacklogPrioritySnooze(
                purchase: purchase,
                previousSnoozedUntil: previousSnoozedUntil,
              );
            },
          ),
        ),
      );
  }

  Future<void> _restoreBacklogPrioritySnooze({
    required SteamPurchase purchase,
    required DateTime? previousSnoozedUntil,
  }) async {
    if (purchase.id == null) {
      return;
    }

    final strings = AppStrings.of(context);

    try {
      // Undo stellt den vorherigen Wert wieder her. Normalerweise ist das null,
      // bei abgelaufenen alten Snoozes bleibt der Zustand dadurch erhalten.
      await _repository.updatePurchase(
        purchase.copyWith(backlogPrioritySnoozedUntil: previousSnoozedUntil),
      );
      await _loadPurchases();
      _showSnackBar(
        strings.backlogPrioritySnoozeRestored(purchase.displayName),
      );
    } catch (error) {
      _showSnackBar(strings.backlogPrioritySnoozeFailed(error));
    }
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

  Future<T?> _runAutomation<T>({
    required String message,
    required Future<T> Function() action,
  }) async {
    // Gemeinsamer Wrapper fuer laenger laufende Aktionen: verhindert parallele
    // Automatisierungen, zeigt Fortschritt und meldet Fehler per SnackBar.
    if (_isAutomationRunning) {
      return null;
    }

    setState(() {
      _isAutomationRunning = true;
    });
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(message)),
              ],
            ),
          );
        },
      ),
    );

    try {
      return await action();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isAutomationRunning = false;
        });
      }
    }
  }

  Future<void> _autoLinkSteamApps() async {
    // Sucht Steam-App-Kandidaten und laesst unsichere Treffer vor dem Speichern
    // im Review-Dialog bestaetigen.
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final candidates = await _runAutomation(
      message: strings.findingSteamAppLinks,
      action: () {
        return _appLinkingService.findCandidates(
          purchases: _purchases,
          language: _steamLanguage(strings),
          countryCode: _steamCountryCode(currency),
        );
      },
    );

    if (!mounted || candidates == null) {
      return;
    }

    if (candidates.isEmpty) {
      _showSnackBar(strings.noSteamAppLinkCandidates);
      return;
    }

    final selectedCandidates = await showDialog<List<SteamAppLinkCandidate>>(
      context: context,
      builder: (context) {
        return _SteamAppLinkReviewDialog(candidates: candidates);
      },
    );

    if (!mounted || selectedCandidates == null || selectedCandidates.isEmpty) {
      return;
    }

    final updatedCount = await _runAutomation(
      message: strings.applyingSteamAppLinks,
      action: () async {
        final steamAppIdsByPurchaseId = <int, int>{
          for (final candidate in selectedCandidates)
            if (candidate.purchase.id != null)
              candidate.purchase.id!: candidate.suggestion.appId,
        };
        final updated = await _repository.updateSteamAppIds(
          steamAppIdsByPurchaseId,
        );
        final linkedPurchases = selectedCandidates.map((candidate) {
          return candidate.purchase.copyWith(
            steamAppId: candidate.suggestion.appId,
          );
        });

        await _metadataService.refreshMetadataForPurchases(
          purchases: linkedPurchases,
          language: _steamLanguage(strings),
          countryCode: _steamCountryCode(currency),
          onlyMissing: true,
        );

        return updated;
      },
    );

    if (!mounted || updatedCount == null) {
      return;
    }

    await _loadPurchases();
    await _collectionsTabKey.currentState?.refresh();
    _showSnackBar(strings.linkedSteamApps(updatedCount));
  }

  Future<void> _syncSteamPlaytime() async {
    // Nutzt die in den Einstellungen hinterlegten Steam-Zugangsdaten und
    // schreibt gefundene Spielzeiten in verknuepfte Kaeufe.
    final strings = AppStrings.of(context);
    final settings =
        AppSettingsScope.maybeOf(context)?.settings ?? const AppSettings();

    if (!settings.hasSteamSyncCredentials) {
      _showSnackBar(strings.steamSyncCredentialsMissing);
      return;
    }

    SteamPlaytimeSyncResult? result;

    try {
      result = await _runAutomation(
        message: strings.syncingSteamPlaytime,
        action: () {
          return _playtimeSyncService.syncPlaytime(
            steamAccountIdentifier: settings.steamAccountIdentifier!,
            apiKey: settings.steamWebApiKey!,
            includePlayedFreeGames: settings.steamIncludePlayedFreeGames,
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final safeError = error is SteamPlaytimeSyncException
          ? error.message
          : strings.unexpectedSteamPlaytimeSyncError;
      _showSnackBar(strings.steamPlaytimeSyncFailed(safeError));
      return;
    }

    if (!mounted || result == null) {
      return;
    }

    await _loadPurchases();
    _showSnackBar(
      strings.syncedSteamPlaytime(
        updated: result.updatedPurchaseCount,
        matched: result.matchedPurchaseCount,
        linked: result.linkedPurchaseCount,
        owned: result.ownedGameCount,
      ),
    );
  }

  Future<void> _refreshMetadataForLinkedPurchases({
    required bool onlyMissing,
  }) async {
    // Aktualisiert Steam-Metadaten fuer Kaeufe mit App-ID. `onlyMissing`
    // begrenzt die Arbeit auf bisher nicht gespeicherte Metadaten.
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final result = await _runAutomation(
      message: onlyMissing
          ? strings.refreshingMissingMetadata
          : strings.refreshingSteamMetadata,
      action: () {
        return _metadataService.refreshMetadataForPurchases(
          purchases: _purchases,
          language: _steamLanguage(strings),
          countryCode: _steamCountryCode(currency),
          onlyMissing: onlyMissing,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    await _collectionsTabKey.currentState?.refresh();
    _showSnackBar(
      strings.refreshedSteamMetadata(
        refreshed: result.refreshed,
        skipped: result.skipped,
        failed: result.failed,
      ),
    );
  }

  Future<void> _createSmartCollectionPresets() async {
    // Legt vordefinierte automatische Sammlungen an, ohne vorhandene
    // gleichnamige Presets doppelt zu erzeugen.
    final strings = AppStrings.of(context);
    final createdCount = await _runAutomation(
      message: strings.creatingSmartCollections,
      action: () async {
        final existingCollections = await _collectionRepository
            .getCollections();
        final existingNames = existingCollections.map((collection) {
          return _normalizeSearchText(collection.name);
        }).toSet();
        final insights = SteamInsights(_purchases);
        final presets = [
          _SmartCollectionPreset(
            name: strings.smartCollectionBacklogPriority,
            description: strings.smartCollectionBacklogPriorityDescription,
            purchases: insights.backlogPriority.map((item) => item.purchase),
          ),
          _SmartCollectionPreset(
            name: strings.smartCollectionExpensiveUnplayed,
            description: strings.smartCollectionExpensiveUnplayedDescription,
            purchases: insights.expensiveUnplayedGames.map(
              (item) => item.purchase,
            ),
          ),
          _SmartCollectionPreset(
            name: strings.smartCollectionStartedBacklog,
            description: strings.smartCollectionStartedBacklogDescription,
            purchases: insights.startedBacklog.map((item) => item.purchase),
          ),
          _SmartCollectionPreset(
            name: strings.smartCollectionHighCostPerHour,
            description: strings.smartCollectionHighCostPerHourDescription,
            purchases: insights.highCostPerHourGames.map(
              (item) => item.purchase,
            ),
          ),
        ];
        var created = 0;

        for (final preset in presets) {
          final normalizedName = _normalizeSearchText(preset.name);

          if (existingNames.contains(normalizedName)) {
            continue;
          }

          final collectionId = await _collectionRepository.insertCollection(
            SteamCollection.create(
              name: preset.name,
              description: preset.description,
            ),
          );
          existingNames.add(normalizedName);
          created++;

          for (final purchase in preset.purchases) {
            final purchaseId = purchase.id;

            if (purchaseId == null) {
              continue;
            }

            await _collectionRepository.addPurchaseToCollection(
              collectionId: collectionId,
              purchaseId: purchaseId,
            );
          }
        }

        return created;
      },
    );

    if (!mounted || createdCount == null) {
      return;
    }

    await _collectionsTabKey.currentState?.refresh();
    _showSnackBar(strings.createdSmartCollections(createdCount));
  }

  Future<void> _importPurchasesFromCsv() async {
    // Datei auswaehlen, Groesse pruefen, CSV parsen und anschliessend als Batch
    // speichern. Bereits vorhandene Kaufzeilen werden beim Speichern erkannt.
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

      final importResult = await _repository.importPurchases(purchases);
      await _lengthEstimateRepository.upsertPurchases(
        importResult.importedPurchases,
      );
      await _loadPurchases();
      _showSnackBar(
        strings.importedPurchases(
          importResult.importedCount,
          skippedDuplicates: importResult.skippedDuplicateCount,
        ),
      );
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

  Future<void> _importLengthEstimatesFromCsv() async {
    // Importiert nur Hintergrunddaten fuer Spiel-Laengen. Es werden keine
    // Kaeufe angelegt und die Kaufuebersicht bleibt unveraendert.
    if (_isCsvOperationRunning) {
      return;
    }

    final strings = AppStrings.of(context);

    setState(() {
      _isCsvOperationRunning = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: strings.importLengthEstimatesCsv,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        lockParentWindow: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final csv = await _readPickedCsvFile(result.files.single);
      final estimates = SteamPurchaseCsv.decodeLengthEstimates(csv);

      if (estimates.isEmpty) {
        _showSnackBar(strings.lengthEstimatesCsvEmpty);
        return;
      }

      final importedCount = await _lengthEstimateRepository.upsertEstimates(
        estimates,
      );
      _showSnackBar(strings.importedLengthEstimates(importedCount));
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
      _throwIfCsvFileIsTooLarge(bytes.length);
      return utf8.decode(bytes, allowMalformed: true);
    }

    final path = file.path;

    if (path == null) {
      throw const SteamPurchaseCsvException(
        'Die ausgewählte Datei konnte nicht gelesen werden.',
      );
    }

    final csvFile = File(path);
    _throwIfCsvFileIsTooLarge(await csvFile.length());

    return csvFile.readAsString();
  }

  void _throwIfCsvFileIsTooLarge(int byteLength) {
    if (byteLength <= SteamPurchaseCsv.maxImportBytes) {
      return;
    }

    final maxMegabytes = SteamPurchaseCsv.maxImportBytes ~/ (1024 * 1024);

    throw SteamPurchaseCsvException(
      'Die ausgewählte CSV ist größer als $maxMegabytes MB.',
    );
  }

  Future<void> _exportPurchasesToCsv() async {
    // Exportiert die aktuell sortierte Kauf-Liste, damit die CSV der sichtbaren
    // Reihenfolge entspricht.
    if (_isCsvOperationRunning) {
      return;
    }

    final strings = AppStrings.of(context);

    setState(() {
      _isCsvOperationRunning = true;
    });

    try {
      final sortedPurchases = _getSortedPurchases(_getStatistics());
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

  Future<void> _exportLengthEstimatesToCsv() async {
    // Exportiert nur die teilbaren Laengenschaetzungen. Private Kaufdaten wie
    // Preise, Spielzeit, Status und Notizen bleiben aus dieser CSV heraus.
    if (_isCsvOperationRunning) {
      return;
    }

    final strings = AppStrings.of(context);

    setState(() {
      _isCsvOperationRunning = true;
    });

    try {
      await _lengthEstimateRepository.upsertPurchases(_purchases);
      final lengthEstimates = await _lengthEstimateRepository.getAllEstimates();

      if (lengthEstimates.isEmpty) {
        _showSnackBar(strings.noLengthEstimatesToExport);
        return;
      }

      final csv = SteamPurchaseCsv.encodeLengthEstimates(lengthEstimates);
      final fileName =
          'steam_length_estimates_${_formatFileDate(DateTime.now())}.csv';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: strings.exportLengthEstimatesCsv,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
        lockParentWindow: true,
      );

      if (path == null) {
        return;
      }

      _showSnackBar(strings.exportedLengthEstimates(lengthEstimates.length));
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
    // Kartenlayout fuer schmale Viewports und kompaktere Listenansichten.
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
              final isCompact = constraints.maxWidth < 560;
              final isMedium = constraints.maxWidth < 760;
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
                return _buildCompactPurchaseCard(
                  purchase: purchase,
                  strings: strings,
                  priceText: _formatCurrency(purchase.price, currency),
                  discountText: discountText,
                  playtimeText: playtimeText,
                  pricePerHourText: pricePerHourText,
                );
              }

              if (isMedium) {
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

  Widget _buildCompactPurchaseCard({
    required SteamPurchase purchase,
    required AppStrings strings,
    required String priceText,
    required String? discountText,
    required String? playtimeText,
    required String? pricePerHourText,
  }) {
    final theme = Theme.of(context);
    final chips = [
      if (discountText != null)
        _buildCompactPurchaseMetricChip(
          icon: Icons.percent,
          label: strings.discount,
          value: discountText,
        ),
      if (playtimeText != null)
        _buildCompactPurchaseMetricChip(
          icon: Icons.timer,
          label: strings.playtime,
          value: playtimeText,
        ),
      if (pricePerHourText != null)
        _buildCompactPurchaseMetricChip(
          icon: Icons.speed,
          label: strings.cost,
          value: pricePerHourText,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPurchaseTitleSection(purchase, strings)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      priceText,
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildCompactPurchaseActionMenu(purchase, strings),
                ],
              ),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ],
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

  Widget _buildCompactPurchaseMetricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildCompactPurchaseActionMenu(
    SteamPurchase purchase,
    AppStrings strings,
  ) {
    return PopupMenuButton<_PurchaseCardAction>(
      tooltip: strings.moreActions,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _PurchaseCardAction.edit:
            _openEditPurchaseScreen(purchase);
            break;
          case _PurchaseCardAction.delete:
            _confirmDeletePurchase(purchase);
            break;
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: _PurchaseCardAction.edit,
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(strings.edit),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: _PurchaseCardAction.delete,
            child: ListTile(
              leading: const Icon(Icons.delete),
              title: Text(strings.delete),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildPurchaseTableHeader(AppStrings strings, AppCurrency currency) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withAlpha(10),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.outline.withAlpha(32)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.purchases,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          _buildPurchaseTableHeaderCell(
            strings.price,
            width: _purchaseTablePriceColumnWidth,
            style: labelStyle,
          ),
          _buildPurchaseTableHeaderCell(
            strings.discount,
            width: _purchaseTableDiscountColumnWidth,
            style: labelStyle,
          ),
          _buildPurchaseTableHeaderCell(
            strings.playtime,
            width: _purchaseTablePlaytimeColumnWidth,
            style: labelStyle,
          ),
          _buildPurchaseTableHeaderCell(
            strings.cost,
            width: _purchaseTableCostColumnWidth,
            style: labelStyle,
          ),
          const SizedBox(width: _purchaseTableActionsColumnWidth),
        ],
      ),
    );
  }

  Widget _buildPurchaseTableHeaderCell(
    String label, {
    required double width,
    required TextStyle? style,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: style,
      ),
    );
  }

  Widget _buildPurchaseTableRow(
    SteamPurchase purchase,
    SteamStatistics stats,
    AppCurrency currency,
  ) {
    // Tabellenlayout fuer breite Viewports. Inhaltlich nutzt es dieselben Werte
    // wie die Kartenansicht.
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final discountText = purchase.discount == null
        ? '-'
        : '${(purchase.discount! * 100).toStringAsFixed(1)} %';
    final playtimeText = _formatPlaytime(purchase.playtimeHours) ?? '-';
    final pricePerHour = stats.pricePerHourForPurchase(purchase);
    final pricePerHourText = pricePerHour == null
        ? '-'
        : _formatPricePerHour(pricePerHour, currency);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.cardTheme.color ?? colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: () => _openEditPurchaseScreen(purchase),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withAlpha(24)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: _buildPurchaseTableTitle(purchase, strings)),
                _buildPurchaseTableValueCell(
                  _formatCurrency(purchase.price, currency),
                  width: _purchaseTablePriceColumnWidth,
                ),
                _buildPurchaseTableValueCell(
                  discountText,
                  width: _purchaseTableDiscountColumnWidth,
                ),
                _buildPurchaseTableValueCell(
                  playtimeText,
                  width: _purchaseTablePlaytimeColumnWidth,
                ),
                _buildPurchaseTableValueCell(
                  pricePerHourText,
                  width: _purchaseTableCostColumnWidth,
                ),
                SizedBox(
                  width: _purchaseTableActionsColumnWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPurchaseActions(purchase, strings),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseTableTitle(SteamPurchase purchase, AppStrings strings) {
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitleParts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseTableValueCell(String value, {required double width}) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
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

  Widget _buildActiveFilterChips(AppStrings strings, AppCurrency currency) {
    final labels = _activeFilterLabels(strings, currency);

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Chip(label: Text(label), visualDensity: VisualDensity.compact),
        ActionChip(
          avatar: const Icon(Icons.clear, size: 18),
          label: Text(strings.clearFilters),
          visualDensity: VisualDensity.compact,
          onPressed: _clearPurchaseFilters,
        ),
      ],
    );
  }

  Widget _buildPurchaseListHeader(
    AppStrings strings,
    AppCurrency currency, {
    bool showTableColumns = false,
  }) {
    // Kopfzeile der Kaufuebersicht mit Suche, Sortierung, Filter und
    // aktivierten Filterchips.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) {
            final isCompact = MediaQuery.sizeOf(context).width < 620;
            final title = Text(
              strings.purchases,
              style: Theme.of(context).textTheme.headlineSmall,
            );
            final sortMenu = DropdownButton<PurchaseSortOption>(
              value: _sortOption,
              isExpanded: true,
              selectedItemBuilder: (context) {
                return PurchaseSortOption.values.map((option) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _getSortLabel(option, strings, currency),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList();
              },
              onChanged: (value) {
                if (value == null || value == _sortOption) {
                  return;
                }

                setState(() {
                  _sortOption = value;
                  _invalidateSortedPurchaseCache();
                });
              },
              items: PurchaseSortOption.values.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(
                    _getSortLabel(option, strings, currency),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            );
            final filterButton = Tooltip(
              message: strings.filters,
              child: OutlinedButton.icon(
                onPressed: () => _openPurchaseFiltersDialog(currency),
                icon: Icon(
                  _purchaseFilters.hasFilters
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                ),
                label: Text(
                  _purchaseFilters.hasFilters
                      ? strings.activeFilterCount(_purchaseFilters.activeCount)
                      : strings.filters,
                ),
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      filterButton,
                      const SizedBox(width: 8),
                      Expanded(child: sortMenu),
                    ],
                  ),
                ],
              );
            }

            final searchField = Expanded(
              child: _buildPurchaseSearchField(strings),
            );

            return Row(
              children: [
                title,
                const SizedBox(width: 20),
                searchField,
                const SizedBox(width: 12),
                filterButton,
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 300,
                  ),
                  child: sortMenu,
                ),
              ],
            );
          },
        ),
        Builder(
          builder: (context) {
            final isCompact = MediaQuery.sizeOf(context).width < 620;

            if (!isCompact) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPurchaseSearchField(strings),
            );
          },
        ),
        if (_purchaseFilters.hasFilters) ...[
          const SizedBox(height: 8),
          _buildActiveFilterChips(strings, currency),
        ],
        if (showTableColumns) ...[
          const SizedBox(height: 12),
          _buildPurchaseTableHeader(strings, currency),
        ],
      ],
    );
  }

  Widget _buildPurchaseSearchField(AppStrings strings) {
    return TextField(
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
                    _invalidateFilteredPurchaseCache();
                  });
                },
                icon: const Icon(Icons.clear),
              ),
      ),
      textInputAction: TextInputAction.search,
      onChanged: (_) {
        setState(() {
          _invalidateFilteredPurchaseCache();
        });
      },
    );
  }

  Widget _buildFloatingActionButton(AppStrings strings) {
    if (_selectedTabIndex == 5) {
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

  List<_HomeDestination> _homeDestinations(AppStrings strings) {
    return [
      _HomeDestination(icon: Icons.dashboard, label: strings.overviewTab),
      _HomeDestination(icon: Icons.bar_chart, label: strings.statisticsTab),
      _HomeDestination(icon: Icons.show_chart, label: strings.chartsTab),
      _HomeDestination(icon: Icons.insights, label: strings.smartInsightsTab),
      _HomeDestination(icon: Icons.track_changes, label: strings.goalsTab),
      _HomeDestination(icon: Icons.folder, label: strings.collectionsTab),
    ];
  }

  PreferredSizeWidget _buildTabBar(AppStrings strings) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kTextTabBarHeight),
      child: Builder(
        builder: (context) {
          final showLabels = MediaQuery.sizeOf(context).width >= 520;
          final destinations = _homeDestinations(strings);

          return TabBar(
            controller: _tabController,
            tabs: destinations.map((destination) {
              return _buildTab(
                icon: destination.icon,
                label: destination.label,
                showLabel: showLabels,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Tab _buildTab({
    required IconData icon,
    required String label,
    required bool showLabel,
  }) {
    final tabIcon = Icon(icon);

    if (showLabel) {
      return Tab(icon: tabIcon, text: label);
    }

    return Tab(
      icon: Tooltip(message: label, child: tabIcon),
    );
  }

  Widget _buildBottomNavigationBar(AppStrings strings) {
    final destinations = _homeDestinations(strings);

    return NavigationBar(
      selectedIndex: _selectedTabIndex,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      onDestinationSelected: (index) {
        if (_selectedTabIndex != index) {
          setState(() {
            _selectedTabIndex = index;
          });
        }
        _tabController.animateTo(index);
      },
      destinations: destinations.map((destination) {
        return NavigationDestination(
          icon: Icon(destination.icon),
          label: destination.label,
          tooltip: destination.label,
        );
      }).toList(),
    );
  }

  double _purchaseListHeaderExtent(
    AppStrings strings,
    AppCurrency currency, {
    required bool showTableColumns,
  }) {
    var extent = 64.0;

    if (_purchaseFilters.hasFilters) {
      final chipCount = _activeFilterLabels(strings, currency).length + 1;
      final chipRows = ((chipCount + 3) / 4).ceil();
      extent += 8 + chipRows * 36;
    }

    if (showTableColumns) {
      extent += 48;
    }

    return extent;
  }

  void _handleHomeAction(_HomeAction action) {
    switch (action) {
      case _HomeAction.autoLinkSteamApps:
        _autoLinkSteamApps();
        break;
      case _HomeAction.syncSteamPlaytime:
        _syncSteamPlaytime();
        break;
      case _HomeAction.refreshMissingMetadata:
        _refreshMetadataForLinkedPurchases(onlyMissing: true);
        break;
      case _HomeAction.refreshAllMetadata:
        _refreshMetadataForLinkedPurchases(onlyMissing: false);
        break;
      case _HomeAction.createSmartCollections:
        _createSmartCollectionPresets();
        break;
      case _HomeAction.importCsv:
        _importPurchasesFromCsv();
        break;
      case _HomeAction.importLengthEstimatesCsv:
        _importLengthEstimatesFromCsv();
        break;
      case _HomeAction.exportCsv:
        _exportPurchasesToCsv();
        break;
      case _HomeAction.exportLengthEstimatesCsv:
        _exportLengthEstimatesToCsv();
        break;
      case _HomeAction.settings:
        _openSettingsScreen();
        break;
    }
  }

  PopupMenuItem<_HomeAction> _buildHomeActionMenuItem({
    required _HomeAction action,
    required IconData icon,
    required String label,
    bool enabled = true,
  }) {
    return PopupMenuItem(
      value: action,
      enabled: enabled,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  List<PopupMenuEntry<_HomeAction>> _buildAutomationMenuItems(
    AppStrings strings,
  ) {
    return [
      _buildHomeActionMenuItem(
        action: _HomeAction.autoLinkSteamApps,
        icon: Icons.link,
        label: strings.autoLinkSteamApps,
        enabled: !_isAutomationRunning,
      ),
      _buildHomeActionMenuItem(
        action: _HomeAction.syncSteamPlaytime,
        icon: Icons.timer,
        label: strings.syncSteamPlaytime,
        enabled: !_isAutomationRunning,
      ),
      _buildHomeActionMenuItem(
        action: _HomeAction.refreshMissingMetadata,
        icon: Icons.cloud_download,
        label: strings.refreshMissingMetadata,
        enabled: !_isAutomationRunning,
      ),
      _buildHomeActionMenuItem(
        action: _HomeAction.refreshAllMetadata,
        icon: Icons.sync,
        label: strings.refreshAllMetadata,
        enabled: !_isAutomationRunning,
      ),
      _buildHomeActionMenuItem(
        action: _HomeAction.createSmartCollections,
        icon: Icons.auto_awesome_motion,
        label: strings.createSmartCollections,
        enabled: !_isAutomationRunning,
      ),
    ];
  }

  List<Widget> _buildAppBarActions(AppStrings strings) {
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    if (isCompact) {
      return [
        PopupMenuButton<_HomeAction>(
          tooltip: strings.moreActions,
          icon: const Icon(Icons.more_vert),
          onSelected: _handleHomeAction,
          itemBuilder: (context) {
            return [
              ..._buildAutomationMenuItems(strings),
              const PopupMenuDivider(),
              _buildHomeActionMenuItem(
                action: _HomeAction.importCsv,
                icon: Icons.upload_file,
                label: strings.importCsv,
                enabled: !_isCsvOperationRunning,
              ),
              _buildHomeActionMenuItem(
                action: _HomeAction.importLengthEstimatesCsv,
                icon: Icons.playlist_add,
                label: strings.importLengthEstimatesCsv,
                enabled: !_isCsvOperationRunning,
              ),
              _buildHomeActionMenuItem(
                action: _HomeAction.exportCsv,
                icon: Icons.download,
                label: strings.exportCsv,
                enabled: !_isCsvOperationRunning,
              ),
              _buildHomeActionMenuItem(
                action: _HomeAction.exportLengthEstimatesCsv,
                icon: Icons.straighten,
                label: strings.exportLengthEstimatesCsv,
                enabled: !_isCsvOperationRunning,
              ),
              _buildHomeActionMenuItem(
                action: _HomeAction.settings,
                icon: Icons.settings,
                label: strings.openSettings,
              ),
            ];
          },
        ),
      ];
    }

    return [
      PopupMenuButton<_HomeAction>(
        tooltip: strings.automation,
        icon: const Icon(Icons.auto_awesome),
        onSelected: _handleHomeAction,
        itemBuilder: (context) => _buildAutomationMenuItems(strings),
      ),
      IconButton(
        tooltip: strings.importCsv,
        onPressed: _isCsvOperationRunning ? null : _importPurchasesFromCsv,
        icon: const Icon(Icons.upload_file),
      ),
      IconButton(
        tooltip: strings.importLengthEstimatesCsv,
        onPressed: _isCsvOperationRunning
            ? null
            : _importLengthEstimatesFromCsv,
        icon: const Icon(Icons.playlist_add),
      ),
      IconButton(
        tooltip: strings.exportCsv,
        onPressed: _isCsvOperationRunning ? null : _exportPurchasesToCsv,
        icon: const Icon(Icons.download),
      ),
      IconButton(
        tooltip: strings.exportLengthEstimatesCsv,
        onPressed: _isCsvOperationRunning ? null : _exportLengthEstimatesToCsv,
        icon: const Icon(Icons.straighten),
      ),
      IconButton(
        tooltip: strings.openSettings,
        onPressed: _openSettingsScreen,
        icon: const Icon(Icons.settings),
      ),
    ];
  }

  List<_DashboardMetric> _dashboardMetrics(
    AppStrings strings,
    SteamStatistics stats,
    AppCurrency currency,
  ) {
    return [
      _DashboardMetric(
        icon: Icons.receipt_long,
        title: strings.purchases,
        value: stats.totalPurchases.toString(),
      ),
      _DashboardMetric(
        icon: Icons.sports_esports,
        title: strings.games,
        value: stats.totalGames.toString(),
      ),
      _DashboardMetric(
        icon: Icons.extension,
        title: strings.dlcs,
        value: stats.totalDlcs.toString(),
      ),
      _DashboardMetric(
        icon: Icons.payments,
        title: strings.totalSpent,
        value: _formatCurrency(stats.totalSpent, currency),
      ),
      _DashboardMetric(
        icon: Icons.percent,
        title: strings.averageDiscount,
        value: stats.averageDiscount == null
            ? '-'
            : '${(stats.averageDiscount! * 100).toStringAsFixed(1)} %',
      ),
      _DashboardMetric(
        icon: Icons.timer,
        title: strings.playtime,
        value: _formatTotalPlaytime(stats.totalPlaytimeHours),
      ),
      _DashboardMetric(
        icon: Icons.speed,
        title: strings.averagePricePerHour(currency.symbol),
        value: stats.pricePerHour == null
            ? '-'
            : _formatPricePerHour(stats.pricePerHour!, currency),
      ),
    ];
  }

  List<Widget> _buildDashboardSlivers({
    required BoxConstraints constraints,
    required AppStrings strings,
    required SteamStatistics stats,
    required AppCurrency currency,
  }) {
    // Dashboard wird als Sliver-Liste gebaut, damit es mit Kaufuebersicht und
    // Headern in einem gemeinsamen ScrollView funktioniert.
    final metrics = _dashboardMetrics(strings, stats, currency);
    final isCompact = constraints.maxWidth < 560;

    if (isCompact) {
      return [
        SliverToBoxAdapter(child: _buildCompactDashboardSummary(metrics)),
      ];
    }

    if (constraints.maxWidth >= 900) {
      return [
        SliverToBoxAdapter(child: _buildDesktopDashboardSummary(metrics)),
      ];
    }

    final isWide = constraints.maxWidth > 700;
    final dashboardColumnCount = constraints.maxWidth > 1200
        ? 5
        : isWide
        ? 3
        : 2;

    return [
      SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: dashboardColumnCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.4 : 1.9,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final metric = metrics[index];

          return StatCard(title: metric.title, value: metric.value);
        }, childCount: metrics.length),
      ),
    ];
  }

  Widget _buildDesktopDashboardSummary(List<_DashboardMetric> metrics) {
    final primaryMetrics = [metrics[3], metrics[0], metrics[5]];
    final secondaryMetrics = [metrics[1], metrics[2], metrics[4], metrics[6]];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final primaryWidth = constraints.maxWidth >= 980
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: primaryMetrics.map((metric) {
                    return SizedBox(
                      width: primaryWidth,
                      child: _buildDashboardHeroMetric(metric),
                    );
                  }).toList(),
                ),
                const Divider(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: secondaryMetrics.map((metric) {
                    return _buildDesktopDashboardFact(metric);
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactDashboardSummary(List<_DashboardMetric> metrics) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryMetric = metrics[3];
    final supportingMetrics = [metrics[0], metrics[1], metrics[5]];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(primaryMetric.icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    primaryMetric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  primaryMetric.value,
                  maxLines: 1,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth < 300
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: supportingMetrics.map((metric) {
                    return SizedBox(
                      width: tileWidth,
                      child: _buildCompactDashboardMetric(metric),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeroMetric(_DashboardMetric metric) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withAlpha(14),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.outline.withAlpha(36)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(metric.icon, size: 28, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDashboardFact(_DashboardMetric metric) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 160, minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withAlpha(32)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(metric.icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            metric.title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            metric.value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDashboardMetric(_DashboardMetric metric) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withAlpha(12),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.outline.withAlpha(34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(metric.icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final stats = _getStatistics();
    final sortedPurchases = _getSortedPurchases(stats);
    final filteredPurchases = _getFilteredPurchases(sortedPurchases, strings);
    final isCompactShell = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: _buildAppBarActions(strings),

        // Auf breiten Layouts bleibt die TabBar oben, mobil wandert die
        // Navigation nach unten und nimmt weniger Raum im Kopfbereich ein.
        bottom: isCompactShell ? null : _buildTabBar(strings),
      ),
      floatingActionButton: _buildFloatingActionButton(strings),
      bottomNavigationBar: isCompactShell
          ? _buildBottomNavigationBar(strings)
          : null,

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
                      final useTableLayout = constraints.maxWidth >= 980;
                      final horizontalInset =
                          constraints.maxWidth > _overviewMaxContentWidth
                          ? (constraints.maxWidth - _overviewMaxContentWidth) /
                                2
                          : 0.0;

                      Widget constrainSliver(Widget sliver) {
                        if (horizontalInset <= 0) {
                          return sliver;
                        }

                        return SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalInset,
                          ),
                          sliver: sliver,
                        );
                      }

                      final purchaseHeader = _buildPurchaseListHeader(
                        strings,
                        currency,
                        showTableColumns: useTableLayout,
                      );
                      final purchaseHeaderSliver = useTableLayout
                          ? SliverPersistentHeader(
                              pinned: true,
                              delegate: _FixedHeaderDelegate(
                                extent: _purchaseListHeaderExtent(
                                  strings,
                                  currency,
                                  showTableColumns: true,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: purchaseHeader,
                                  ),
                                ),
                              ),
                            )
                          : SliverToBoxAdapter(child: purchaseHeader);

                      return CustomScrollView(
                        slivers: [
                          constrainSliver(
                            SliverToBoxAdapter(
                              child: Text(
                                strings.dashboard,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          ..._buildDashboardSlivers(
                            constraints: constraints,
                            strings: strings,
                            stats: stats,
                            currency: currency,
                          ).map(constrainSliver),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          constrainSliver(purchaseHeaderSliver),
                          if (!useTableLayout)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 12),
                            ),
                          if (_purchases.isEmpty)
                            constrainSliver(
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(child: Text(strings.noPurchases)),
                              ),
                            )
                          else if (filteredPurchases.isEmpty)
                            constrainSliver(
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(strings.noMatchingPurchases),
                                ),
                              ),
                            )
                          else
                            constrainSliver(
                              SliverList.builder(
                                itemCount: filteredPurchases.length,
                                itemBuilder: (context, index) {
                                  final purchase = filteredPurchases[index];

                                  if (useTableLayout) {
                                    return _buildPurchaseTableRow(
                                      purchase,
                                      stats,
                                      currency,
                                    );
                                  }

                                  return _buildPurchaseCard(
                                    purchase,
                                    stats,
                                    currency,
                                  );
                                },
                              ),
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

                // TAB 4: Auswertungen für Backlog und Pile of Shame.
                SmartInsightsTab(
                  purchases: _purchases,
                  onPurchaseTap: _openEditPurchaseScreen,
                  onBacklogPrioritySnooze: _snoozeBacklogPriority,
                ),

                // TAB 5: Ziele für Ausgaben, Backlog und Abschlussquote.
                GoalsTab(purchases: _purchases, goalStore: _goalStore),

                // TAB 6: Manuelle Kollektionen als stabile Grundlage.
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

/// Zieldefinition fuer NavigationBar/NavigationRail.
class _HomeDestination {
  final IconData icon;
  final String label;

  const _HomeDestination({required this.icon, required this.label});
}

/// Dashboard-Kennzahl mit Icon, Titel und Wert.
class _DashboardMetric {
  final IconData icon;
  final String title;
  final String value;

  const _DashboardMetric({
    required this.icon,
    required this.title,
    required this.value,
  });
}

/// Sliver-Header, der die Kaufuebersicht beim Scrollen oben halten kann.
class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  const _FixedHeaderDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _FixedHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}

/// Definition einer automatisch anzulegenden Smart-Kollektion.
class _SmartCollectionPreset {
  final String name;
  final String description;
  final Iterable<SteamPurchase> purchases;

  const _SmartCollectionPreset({
    required this.name,
    required this.description,
    required this.purchases,
  });
}

/// Review-Dialog fuer automatisch gefundene Steam-App-Verknuepfungen.
class _SteamAppLinkReviewDialog extends StatefulWidget {
  final List<SteamAppLinkCandidate> candidates;

  const _SteamAppLinkReviewDialog({required this.candidates});

  @override
  State<_SteamAppLinkReviewDialog> createState() =>
      _SteamAppLinkReviewDialogState();
}

class _SteamAppLinkReviewDialogState extends State<_SteamAppLinkReviewDialog> {
  // Hochsichere Kandidaten sind standardmaessig ausgewaehlt, unsicherere kann
  // der Nutzer manuell hinzunehmen.
  late final Set<int> _selectedPurchaseIds = widget.candidates
      .where((candidate) => candidate.isHighConfidence)
      .map((candidate) => candidate.purchase.id)
      .whereType<int>()
      .toSet();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final selectedCandidates = widget.candidates.where((candidate) {
      final purchaseId = candidate.purchase.id;

      return purchaseId != null && _selectedPurchaseIds.contains(purchaseId);
    }).toList();

    return AlertDialog(
      title: Text(strings.steamAppLinkReviewTitle),
      content: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.steamAppLinkReviewDescription),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.candidates.length,
                itemBuilder: (context, index) {
                  final candidate = widget.candidates[index];
                  final purchaseId = candidate.purchase.id;
                  final isSelected =
                      purchaseId != null &&
                      _selectedPurchaseIds.contains(purchaseId);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: purchaseId == null
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selectedPurchaseIds.add(purchaseId);
                              } else {
                                _selectedPurchaseIds.remove(purchaseId);
                              }
                            });
                          },
                    title: Text(
                      candidate.purchase.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${candidate.suggestion.name} · '
                      '${strings.steamApp}: ${candidate.suggestion.appId} · '
                      '${strings.confidence}: '
                      '${(candidate.confidence * 100).round()}%',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: Icon(
                      candidate.isHighConfidence
                          ? Icons.verified
                          : Icons.help_outline,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton.icon(
          onPressed: selectedCandidates.isEmpty
              ? null
              : () => Navigator.of(context).pop(selectedCandidates),
          icon: const Icon(Icons.link),
          label: Text(strings.linkSelectedSteamApps),
        ),
      ],
    );
  }
}
