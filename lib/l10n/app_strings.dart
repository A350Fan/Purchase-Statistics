import 'package:flutter/widgets.dart';

import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';

class AppStrings {
  static const supportedLocales = [Locale('de'), Locale('en')];

  final Locale locale;

  const AppStrings._(this.locale);

  static AppStrings forLocale(Locale locale) {
    if (locale.languageCode == 'en') {
      return const AppStrings._(Locale('en'));
    }

    return const AppStrings._(Locale('de'));
  }

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppTextScope>();

    return scope?.strings ?? const AppStrings._(Locale('de'));
  }

  bool get isEnglish => locale.languageCode == 'en';

  String get appTitle => 'Purchase Statistics';
  String get dashboard => isEnglish ? 'Dashboard' : 'Dashboard';
  String get purchases => isEnglish ? 'Purchases' : 'Käufe';
  String get games => isEnglish ? 'Games' : 'Spiele';
  String get dlcs => isEnglish ? 'DLCs' : 'DLCs';
  String get allPurchaseTypes => isEnglish ? 'All' : 'Alle';
  String get totalSpent => isEnglish ? 'Total spent' : 'Gesamtausgaben';
  String get averageDiscount => isEnglish ? 'Avg. discount' : 'Ø Rabatt';
  String get playtime => isEnglish ? 'Playtime' : 'Spielzeit';
  String averagePricePerHour(String currencySymbol) {
    return isEnglish ? 'Avg. $currencySymbol/h' : 'Ø $currencySymbol/h';
  }

  String get overviewTab => isEnglish ? 'Overview' : 'Übersicht';
  String get statisticsTab => isEnglish ? 'Statistics' : 'Statistik';
  String get chartsTab => isEnglish ? 'Charts' : 'Diagramme';
  String get smartInsightsTab => isEnglish ? 'Insights' : 'Insights';
  String get goalsTab => isEnglish ? 'Goals' : 'Ziele';
  String get collectionsTab => isEnglish ? 'Collections' : 'Kollektionen';
  String get purchaseFab => isEnglish ? 'Purchase' : 'Kauf';
  String get collectionFab => isEnglish ? 'Collection' : 'Kollektion';
  String get importCsv => isEnglish ? 'Import CSV' : 'CSV importieren';
  String get exportCsv => isEnglish ? 'Export CSV' : 'CSV exportieren';
  String get openSettings => isEnglish ? 'Settings' : 'Einstellungen';
  String get moreActions => isEnglish ? 'More actions' : 'Weitere Aktionen';
  String get automation => isEnglish ? 'Automation' : 'Automatisierung';
  String get autoLinkSteamApps =>
      isEnglish ? 'Auto-link Steam apps' : 'Steam-Apps automatisch verknüpfen';
  String get syncSteamPlaytime =>
      isEnglish ? 'Sync Steam playtime' : 'Steam-Spielzeit synchronisieren';
  String get refreshMissingMetadata =>
      isEnglish ? 'Load missing metadata' : 'Fehlende Metadaten laden';
  String get refreshAllMetadata =>
      isEnglish ? 'Refresh all metadata' : 'Alle Metadaten aktualisieren';
  String get createSmartCollections =>
      isEnglish ? 'Create smart collections' : 'Smart-Kollektionen anlegen';
  String get findingSteamAppLinks => isEnglish
      ? 'Searching Steam app matches...'
      : 'Steam-App-Treffer werden gesucht...';
  String get applyingSteamAppLinks => isEnglish
      ? 'Applying Steam app links...'
      : 'Steam-App-Verknüpfungen werden gespeichert...';
  String get syncingSteamPlaytime => isEnglish
      ? 'Syncing Steam playtime...'
      : 'Steam-Spielzeit wird synchronisiert...';
  String get refreshingMissingMetadata => isEnglish
      ? 'Loading missing Steam metadata...'
      : 'Fehlende Steam-Metadaten werden geladen...';
  String get refreshingSteamMetadata => isEnglish
      ? 'Refreshing Steam metadata...'
      : 'Steam-Metadaten werden aktualisiert...';
  String get creatingSmartCollections => isEnglish
      ? 'Creating smart collections...'
      : 'Smart-Kollektionen werden angelegt...';
  String get noSteamAppLinkCandidates => isEnglish
      ? 'No Steam app matches found for unlinked purchases.'
      : 'Keine Steam-App-Treffer für unverknüpfte Käufe gefunden.';
  String linkedSteamApps(int count) {
    if (isEnglish) {
      return count == 1
          ? '1 Steam app was linked.'
          : '$count Steam apps were linked.';
    }

    return count == 1
        ? '1 Steam-App wurde verknüpft.'
        : '$count Steam-Apps wurden verknüpft.';
  }

  String get steamSyncCredentialsMissing => isEnglish
      ? 'Add your Steam account and Web API key in Settings first.'
      : 'Hinterlege zuerst Steam-Account und Web-API-Key in den Einstellungen.';

  String syncedSteamPlaytime({
    required int updated,
    required int matched,
    required int linked,
    required int owned,
  }) {
    if (isEnglish) {
      return 'Steam playtime synced: $updated updated, $matched/$linked linked purchases matched, $owned owned games found.';
    }

    return 'Steam-Spielzeit synchronisiert: $updated aktualisiert, $matched/$linked verknüpfte Käufe gefunden, $owned Steam-Spiele geladen.';
  }

  String steamPlaytimeSyncFailed(Object error) {
    return isEnglish
        ? 'Steam playtime could not be synced: $error'
        : 'Steam-Spielzeit konnte nicht synchronisiert werden: $error';
  }

  String refreshedSteamMetadata({
    required int refreshed,
    required int skipped,
    required int failed,
  }) {
    if (isEnglish) {
      return 'Metadata refreshed: $refreshed, skipped: $skipped, failed: $failed.';
    }

    return 'Metadaten aktualisiert: $refreshed, übersprungen: $skipped, fehlgeschlagen: $failed.';
  }

  String createdSmartCollections(int count) {
    if (isEnglish) {
      return count == 1
          ? '1 smart collection was created.'
          : '$count smart collections were created.';
    }

    return count == 1
        ? '1 Smart-Kollektion wurde angelegt.'
        : '$count Smart-Kollektionen wurden angelegt.';
  }

  String get steamAppLinkReviewTitle =>
      isEnglish ? 'Review Steam app links' : 'Steam-App-Verknüpfungen prüfen';
  String get steamAppLinkReviewDescription => isEnglish
      ? 'Only selected matches will be written. High-confidence matches are preselected.'
      : 'Nur ausgewählte Treffer werden gespeichert. Sehr sichere Treffer sind vorausgewählt.';
  String get confidence => isEnglish ? 'Confidence' : 'Sicherheit';
  String get linkSelectedSteamApps =>
      isEnglish ? 'Link selected' : 'Ausgewählte verknüpfen';
  String get edit => isEnglish ? 'Edit' : 'Bearbeiten';
  String get delete => isEnglish ? 'Delete' : 'Löschen';
  String get undo => isEnglish ? 'Undo' : 'Rückgängig';
  String get purchaseSearch => isEnglish ? 'Search purchases' : 'Käufe suchen';
  String get clearSearch => isEnglish ? 'Clear search' : 'Suche löschen';
  String get filters => isEnglish ? 'Filters' : 'Filter';
  String activeFilterCount(int count) {
    return isEnglish ? 'Filters ($count)' : 'Filter ($count)';
  }

  String get clearFilters =>
      isEnglish ? 'Clear filters' : 'Filter zurücksetzen';
  String get resetFilters => isEnglish ? 'Reset' : 'Zurücksetzen';
  String get applyFilters => isEnglish ? 'Apply' : 'Anwenden';
  String get purchaseFiltersTitle =>
      isEnglish ? 'Filter purchases' : 'Käufe filtern';
  String get status => isEnglish ? 'Status' : 'Status';
  String statusFilterCount(int count) {
    return isEnglish ? 'Status: $count selected' : 'Status: $count ausgewählt';
  }

  String get purchaseYearFilter => isEnglish ? 'Purchase year' : 'Kaufjahr';
  String get allYears => isEnglish ? 'All years' : 'Alle Jahre';
  String get priceRange => isEnglish ? 'Price range' : 'Preisbereich';
  String get minPrice => isEnglish ? 'Min.' : 'Min.';
  String get maxPrice => isEnglish ? 'Max.' : 'Max.';
  String get priceRangeInvalid => isEnglish
      ? 'Minimum must not be higher than maximum'
      : 'Minimum darf nicht höher als Maximum sein';
  String get playtimeFilter => isEnglish ? 'Playtime' : 'Spielzeit';
  String get allPlaytime => isEnglish ? 'All' : 'Alle';
  String get withFilter => isEnglish ? 'With' : 'Mit';
  String get withoutFilter => isEnglish ? 'Without' : 'Ohne';
  String get withPlaytime => isEnglish ? 'With playtime' : 'Mit Spielzeit';
  String get withoutPlaytime =>
      isEnglish ? 'Without playtime' : 'Ohne Spielzeit';
  String get discountFilter => isEnglish ? 'Discount' : 'Rabatt';
  String get allDiscounts => isEnglish ? 'All' : 'Alle';
  String get withDiscount => isEnglish ? 'With discount' : 'Mit Rabatt';
  String get withoutDiscount => isEnglish ? 'Without discount' : 'Ohne Rabatt';
  String get noPurchases => isEnglish
      ? 'No purchases yet. Add your first Steam purchase.'
      : 'Noch keine Käufe vorhanden. Füge deinen ersten Steam-Kauf hinzu.';
  String get noStatisticsData => isEnglish
      ? 'No statistics data yet.'
      : 'Noch keine Statistikdaten vorhanden.';
  String get noChartData =>
      isEnglish ? 'No chart data yet.' : 'Noch keine Diagrammdaten vorhanden.';
  String get noInsightsData =>
      isEnglish ? 'No insights yet.' : 'Noch keine Insights vorhanden.';
  String get editGoals => isEnglish ? 'Edit goals' : 'Ziele bearbeiten';
  String get annualSpendingGoal =>
      isEnglish ? 'Annual spending' : 'Jahresausgaben';
  String get backlogLimitGoal => isEnglish ? 'Backlog limit' : 'Backlog-Limit';
  String get unplayedBacklogGoal =>
      isEnglish ? 'Unplayed limit' : 'Ungespielt-Limit';
  String get unplayedBacklogValueGoal =>
      isEnglish ? 'Unplayed value' : 'Ungespielt-Wert';
  String get completionRateGoal =>
      isEnglish ? 'Completion rate' : 'Abschlussquote';
  String get goalNotSet => isEnglish ? 'No target set' : 'Kein Ziel gesetzt';
  String goalTarget(String value) {
    return isEnglish ? 'Target: $value' : 'Ziel: $value';
  }

  String goalProjection(String value) {
    return isEnglish ? 'Projection: $value' : 'Prognose: $value';
  }

  String get goalStateUnset => isEnglish ? 'Unset' : 'Offen';
  String get goalStateOnTrack => isEnglish ? 'On track' : 'Im Plan';
  String get goalStateAtRisk => isEnglish ? 'At risk' : 'Gefährdet';
  String get goalStateOffTrack => isEnglish ? 'Off track' : 'Abweichung';
  String get annualSpendingLimitOptional =>
      isEnglish ? 'Annual spending limit optional' : 'Jahresbudget optional';
  String get backlogLimitOptional =>
      isEnglish ? 'Backlog limit optional' : 'Backlog-Limit optional';
  String get unplayedBacklogLimitOptional => isEnglish
      ? 'Unplayed backlog limit optional'
      : 'Ungespielt-Limit optional';
  String get unplayedBacklogValueLimitOptional => isEnglish
      ? 'Unplayed backlog value limit optional'
      : 'Ungespielt-Wert-Limit optional';
  String get completionRateTargetOptional => isEnglish
      ? 'Completion rate target optional'
      : 'Abschlussquote-Ziel optional';
  String get valueCannotBeNegative =>
      isEnglish ? 'Value cannot be negative' : 'Wert darf nicht negativ sein';
  String get percentOutOfRange => isEnglish
      ? 'Percent must be between 0 and 100'
      : 'Prozentwert muss zwischen 0 und 100 liegen';
  String get noCollections => isEnglish
      ? 'No collections yet. Create your first collection.'
      : 'Noch keine Kollektionen vorhanden. Erstelle deine erste Kollektion.';
  String get noCollectionItems => isEnglish
      ? 'No purchases in this collection yet.'
      : 'Noch keine Käufe in dieser Kollektion.';
  String get noAutomaticCollectionItems => isEnglish
      ? 'No purchases match this rule yet.'
      : 'Noch keine Käufe passen zu dieser Regel.';
  String purchaseCount(int count) {
    if (isEnglish) {
      return count == 1 ? '1 purchase' : '$count purchases';
    }

    return count == 1 ? '1 Kauf' : '$count Käufe';
  }

  String get noData => isEnglish ? 'No data' : 'Keine Daten';
  String get backlog => isEnglish ? 'Backlog' : 'Backlog';
  String get backlogValue => isEnglish ? 'Backlog value' : 'Backlog-Wert';
  String get unplayedBacklog => isEnglish ? 'Unplayed' : 'Ungespielt';
  String get unplayedBacklogValue =>
      isEnglish ? 'Unplayed value' : 'Ungespielt-Wert';
  String get completionRate => isEnglish ? 'Completion rate' : 'Abschlussquote';
  String get backlogPriority =>
      isEnglish ? 'Play next' : 'Als Nächstes angehen';
  String get backlogPriorityDescription => isEnglish
      ? 'Open games with no or little playtime, weighted by value and age.'
      : 'Offene Spiele mit keiner oder wenig Spielzeit, gewichtet nach Wert und Alter.';
  String get expensiveUnplayedGames =>
      isEnglish ? 'Expensive and unplayed' : 'Teuer & ungespielt';
  String get startedBacklogGames =>
      isEnglish ? 'Started but open' : 'Angefangen, aber offen';
  String get highCostPerHourGames =>
      isEnglish ? 'High cost per hour' : 'Hohe Kosten pro Stunde';
  String get abandonedSpend =>
      isEnglish ? 'Abandoned spend' : 'Abgebrochene Ausgaben';
  String get statusReviewGames => isEnglish ? 'Review status' : 'Status prüfen';
  String get statusReviewDescription => isEnglish
      ? 'Games with plenty of playtime but no status. They probably should not be backlog anymore.'
      : 'Spiele mit viel Spielzeit, aber ohne Status. Die gehören wahrscheinlich nicht mehr in den Backlog.';
  String get smartCollectionBacklogPriority =>
      isEnglish ? 'Smart: Play next' : 'Smart: Als Nächstes angehen';
  String get smartCollectionBacklogPriorityDescription => isEnglish
      ? 'Created from the current backlog priority insights.'
      : 'Aus den aktuellen Backlog-Prioritäten erstellt.';
  String get smartCollectionExpensiveUnplayed =>
      isEnglish ? 'Smart: Expensive and unplayed' : 'Smart: Teuer & ungespielt';
  String get smartCollectionExpensiveUnplayedDescription => isEnglish
      ? 'Unplayed backlog games sorted by tied-up value.'
      : 'Ungespielte Backlog-Spiele mit hohem gebundenem Wert.';
  String get smartCollectionStartedBacklog =>
      isEnglish ? 'Smart: Started backlog' : 'Smart: Angefangener Backlog';
  String get smartCollectionStartedBacklogDescription => isEnglish
      ? 'Started games that are still open.'
      : 'Angefangene Spiele, die noch offen sind.';
  String get smartCollectionHighCostPerHour =>
      isEnglish ? 'Smart: High cost per hour' : 'Smart: Hohe Kosten pro Stunde';
  String get smartCollectionHighCostPerHourDescription => isEnglish
      ? 'Backlog games where the current value per played hour is still high.'
      : 'Backlog-Spiele mit aktuell hohen Kosten pro gespielter Stunde.';
  String get priority => isEnglish ? 'Priority' : 'Priorität';
  String get priorityHigh => isEnglish ? 'High' : 'Hoch';
  String get priorityMedium => isEnglish ? 'Medium' : 'Mittel';
  String get priorityLow => isEnglish ? 'Low' : 'Niedrig';
  String get noPlaytime => isEnglish ? 'No playtime' : 'Keine Spielzeit';
  String get noInsightItems => isEnglish ? 'No matches.' : 'Keine Treffer.';
  String get reasonMissingStatus =>
      isEnglish ? 'Missing status' : 'Status fehlt';
  String get reasonNoPlaytime =>
      isEnglish ? 'No playtime saved' : 'Keine Spielzeit erfasst';
  String get reasonBarelyStarted =>
      isEnglish ? 'Barely started' : 'Kaum gestartet';
  String get reasonOpen => isEnglish ? 'Open' : 'Offen';
  String get reasonActive => isEnglish ? 'Active' : 'Aktiv';
  String get reasonExpensive => isEnglish ? 'High value' : 'Hoher Wert';
  String get reasonOld => isEnglish ? 'Long in backlog' : 'Lange im Backlog';
  String get reasonHighCostPerHour =>
      isEnglish ? 'High cost/hour' : 'Hohe Kosten/Stunde';
  String get reasonWellPlayed => isEnglish ? 'Well played' : 'Viel gespielt';
  String get reasonShortGame => isEnglish ? 'Short game' : 'Kurzes Spiel';
  String get reasonNearlyFinished =>
      isEnglish ? 'Nearly finished' : 'Fast fertig';
  String estimatedLength(String hours) {
    return isEnglish ? 'Length: $hours h' : 'Länge: $hours h';
  }

  String estimatedProgress(String percent) {
    return isEnglish ? 'Progress: $percent' : 'Fortschritt: $percent';
  }

  String get price => isEnglish ? 'Price' : 'Preis';
  String get discount => isEnglish ? 'Discount' : 'Rabatt';
  String get cost => isEnglish ? 'Cost' : 'Kosten';
  String get game => isEnglish ? 'Game' : 'Spiel';
  String get dlc => 'DLC';
  String get gameStatusOptional =>
      isEnglish ? 'Status optional' : 'Status optional';
  String get noGameStatus => isEnglish ? 'No status' : 'Kein Status';
  String gameStatusLabel(SteamGameStatus status) {
    return switch (status) {
      SteamGameStatus.open => isEnglish ? 'Open' : 'Offen',
      SteamGameStatus.active => isEnglish ? 'Active' : 'Aktiv',
      SteamGameStatus.completed => isEnglish ? 'Completed' : 'Durchgespielt',
      SteamGameStatus.endless => isEnglish ? 'Endless' : 'Endlos',
      SteamGameStatus.abandoned => isEnglish ? 'Abandoned' : 'Abgebrochen',
      SteamGameStatus.archived => isEnglish ? 'Archived' : 'Archiviert',
    };
  }

  String get deletePurchaseTitle =>
      isEnglish ? 'Delete purchase?' : 'Kauf löschen?';
  String deletePurchaseMessage(String purchaseName) {
    return isEnglish
        ? 'Do you really want to delete "$purchaseName"?'
        : 'Möchtest du "$purchaseName" wirklich löschen?';
  }

  String get cancel => isEnglish ? 'Cancel' : 'Abbrechen';
  String get csvEmpty => isEnglish
      ? 'The CSV does not contain any purchases.'
      : 'Die CSV enthält keine Käufe.';
  String importedPurchases(int count) {
    if (isEnglish) {
      return count == 1
          ? '1 purchase was imported.'
          : '$count purchases were imported.';
    }

    return count == 1
        ? '1 Kauf wurde importiert.'
        : '$count Käufe wurden importiert.';
  }

  String exportedPurchases(int count) {
    if (isEnglish) {
      return count == 1
          ? '1 purchase was exported.'
          : '$count purchases were exported.';
    }

    return count == 1
        ? '1 Kauf wurde exportiert.'
        : '$count Käufe wurden exportiert.';
  }

  String deletedPurchase(String purchaseName) {
    return isEnglish
        ? '"$purchaseName" was deleted.'
        : '"$purchaseName" wurde gelöscht.';
  }

  String get createCollectionTitle =>
      isEnglish ? 'Create collection' : 'Kollektion erstellen';
  String get editCollectionTitle =>
      isEnglish ? 'Edit collection' : 'Kollektion bearbeiten';
  String get collectionType => isEnglish ? 'Collection type' : 'Kollektionstyp';
  String get manualCollection => isEnglish ? 'Manual' : 'Manuell';
  String get automaticCollection => isEnglish ? 'Automatic' : 'Automatisch';
  String get collectionName => isEnglish ? 'Name' : 'Name';
  String get collectionDescriptionOptional =>
      isEnglish ? 'Description optional' : 'Beschreibung optional';
  String get enterCollectionName =>
      isEnglish ? 'Enter a collection name' : 'Bitte Namen eingeben';
  String get collectionRule => isEnglish ? 'Rule' : 'Regel';
  String get titleContainsRule =>
      isEnglish ? 'Title contains' : 'Titel enthält';
  String get titleSearchTerm =>
      isEnglish ? 'Title search term' : 'Titel-Suchbegriff';
  String get enterTitleSearchTerm => isEnglish
      ? 'Enter a title search term'
      : 'Bitte Titel-Suchbegriff eingeben';
  String get metadataField => isEnglish ? 'Metadata field' : 'Metadatenfeld';
  String get metadataValue => isEnglish ? 'Metadata value' : 'Metadatenwert';
  String get enterMetadataValue =>
      isEnglish ? 'Enter a metadata value' : 'Bitte Metadatenwert eingeben';
  String get loadingMetadataValues =>
      isEnglish ? 'Loading values...' : 'Werte werden geladen...';
  String get noMetadataValuesAvailable =>
      isEnglish ? 'No values available yet' : 'Noch keine Werte verfügbar';
  String get includeDlcsInAutomaticCollection =>
      isEnglish ? 'Include DLCs' : 'DLCs einschließen';
  String get automaticCollectionGamesOnly =>
      isEnglish ? 'Games only' : 'Nur Spiele';
  String get automaticCollectionGamesAndDlcs =>
      isEnglish ? 'Games and DLCs' : 'Spiele und DLCs';
  String get metadataGenre => isEnglish ? 'Genre' : 'Genre';
  String get metadataTag => isEnglish ? 'Tag' : 'Tag';
  String get metadataDeveloper => isEnglish ? 'Developer' : 'Entwickler';
  String get metadataPublisher => isEnglish ? 'Publisher' : 'Publisher';
  String get metadataPreview =>
      isEnglish ? 'Steam metadata' : 'Steam-Metadaten';
  String get loadingMetadata =>
      isEnglish ? 'Loading metadata...' : 'Metadaten werden geladen...';
  String get noMetadataPreview => isEnglish
      ? 'No metadata cached for this Steam app yet.'
      : 'Für diese Steam-App sind noch keine Metadaten gespeichert.';
  String automaticCollectionRule(String field, String value) {
    return '$field: $value';
  }

  String createdCollection(String collectionName) {
    return isEnglish
        ? '"$collectionName" was created.'
        : '"$collectionName" wurde erstellt.';
  }

  String updatedCollection(String collectionName) {
    return isEnglish
        ? '"$collectionName" was updated.'
        : '"$collectionName" wurde aktualisiert.';
  }

  String get deleteCollectionTitle =>
      isEnglish ? 'Delete collection?' : 'Kollektion löschen?';
  String deleteCollectionMessage(String collectionName) {
    return isEnglish
        ? 'Do you really want to delete "$collectionName"?'
        : 'Möchtest du "$collectionName" wirklich löschen?';
  }

  String deletedCollection(String collectionName) {
    return isEnglish
        ? '"$collectionName" was deleted.'
        : '"$collectionName" wurde gelöscht.';
  }

  String get removeFromCollection =>
      isEnglish ? 'Remove from collection' : 'Aus Kollektion entfernen';
  String removedPurchaseFromCollection(
    String purchaseName,
    String collectionName,
  ) {
    return isEnglish
        ? '"$purchaseName" was removed from "$collectionName".'
        : '"$purchaseName" wurde aus "$collectionName" entfernt.';
  }

  String get addPurchaseToCollection =>
      isEnglish ? 'Add purchase' : 'Kauf hinzufügen';
  String get selectPurchaseForCollection =>
      isEnglish ? 'Select purchase' : 'Kauf auswählen';
  String get collectionsForPurchase =>
      isEnglish ? 'Collections' : 'Kollektionen';
  String get noCollectionsForPurchase => isEnglish
      ? 'No collections available yet.'
      : 'Noch keine Kollektionen verfügbar.';
  String get sortPurchasesBy =>
      isEnglish ? 'Sort purchases by' : 'Käufe sortieren nach';
  String get purchaseTypeFilter => isEnglish ? 'Purchase type' : 'Kaufart';
  String get sortByName => isEnglish ? 'Name' : 'Name';
  String get sortByNewest => isEnglish ? 'Newest first' : 'Neueste zuerst';
  String get sortByOldest => isEnglish ? 'Oldest first' : 'Älteste zuerst';
  String get moveUp => isEnglish ? 'Move up' : 'Nach oben';
  String get moveDown => isEnglish ? 'Move down' : 'Nach unten';
  String get collectionSortManual =>
      isEnglish ? 'Manual order' : 'Manuelle Reihenfolge';
  String get collectionSortReleaseAsc =>
      isEnglish ? 'Release date: oldest first' : 'Release: älteste zuerst';
  String get collectionSortReleaseDesc =>
      isEnglish ? 'Release date: newest first' : 'Release: neueste zuerst';
  String get noAvailablePurchasesForCollection => isEnglish
      ? 'No purchases available to add.'
      : 'Keine Käufe zum Hinzufügen verfügbar.';
  String get noMatchingPurchases =>
      isEnglish ? 'No matching purchases found.' : 'Keine passenden Käufe.';
  String addedPurchaseToCollection(String purchaseName, String collectionName) {
    return isEnglish
        ? '"$purchaseName" was added to "$collectionName".'
        : '"$purchaseName" wurde zu "$collectionName" hinzugefügt.';
  }

  String get missingPurchase =>
      isEnglish ? 'Deleted purchase' : 'Gelöschter Kauf';

  String csvImportFailed(Object error) {
    return isEnglish
        ? 'CSV could not be imported: $error'
        : 'CSV konnte nicht importiert werden: $error';
  }

  String csvExportFailed(Object error) {
    return isEnglish
        ? 'CSV could not be exported: $error'
        : 'CSV konnte nicht exportiert werden: $error';
  }

  String get annualValues => isEnglish ? 'Annual values' : 'Jahreswerte';
  String get year => isEnglish ? 'Year' : 'Jahr';
  String get spending => isEnglish ? 'Spending' : 'Ausgaben';
  String get cumulative => isEnglish ? 'Cumulative' : 'Kumulativ';
  String get average => isEnglish ? 'Average' : 'Mittelwert';
  String get total => isEnglish ? 'Total' : 'Summe';
  String get totalOriginalPrice => isEnglish ? 'Total MSRP' : 'Summe UVP';
  String get quarter => isEnglish ? 'Quarter' : 'Quartal';
  String get selectYearQuestion => isEnglish
      ? 'Which year should be analyzed?'
      : 'Welches Jahr soll ausgewertet werden?';
  String get projectedAverage => isEnglish ? 'Average*' : 'Mittelwert*';
  String get projectedTotal => isEnglish ? 'Total*' : 'Summe*';
  String get soFar => isEnglish ? 'So far' : 'Bisher';
  String get runningYearProjection => isEnglish
      ? '* current year is projected'
      : '* laufendes Jahr wird hochgerechnet';
  String get discountDataNote => isEnglish
      ? 'Avg. discount: only purchases with known MSRP'
      : 'Ø Rabatt: nur Käufe mit bekanntem UVP';
  String pricePerHourDataNote(String currencySymbol) {
    return isEnglish
        ? '$currencySymbol/h: requires saved playtime'
        : '$currencySymbol/h: benötigt gespeicherte Spielzeit';
  }

  String get notAvailable => isEnglish ? 'N/A' : 'N/V';
  String get annualSpendingChart =>
      isEnglish ? 'Spending per year' : 'Ausgaben pro Jahr';
  String get quarterlySpendingChart =>
      isEnglish ? 'Spending per quarter' : 'Ausgaben pro Quartal';
  String get annualDiscountChart =>
      isEnglish ? 'Discount per year' : 'Rabatt pro Jahr';
  String get quarterlyDiscountChart =>
      isEnglish ? 'Discount per quarter' : 'Rabatt pro Quartal';
  String get cumulativeSpendingChart =>
      isEnglish ? 'Cumulative spending' : 'Gesamtausgaben';
  String get selectedYearCumulativeSpendingChart => isEnglish
      ? 'Cumulative spending in selected year'
      : 'Gesamtausgaben im gewählten Jahr';

  String get settingsTitle => isEnglish ? 'Settings' : 'Einstellungen';
  String get appearance => isEnglish ? 'Appearance' : 'Darstellung';
  String get system => isEnglish ? 'System' : 'System';
  String get light => isEnglish ? 'Light' : 'Hell';
  String get dark => isEnglish ? 'Dark' : 'Dunkel';
  String get language => isEnglish ? 'Language' : 'Sprache';
  String get german => isEnglish ? 'German' : 'Deutsch';
  String get english => isEnglish ? 'English' : 'Englisch';
  String get currency => isEnglish ? 'Currency' : 'Währung';
  String currencyLabel(AppCurrency currency) {
    return switch (currency) {
      AppCurrency.eur => 'Euro (€)',
      AppCurrency.usd => isEnglish ? 'US dollar (\$)' : 'US-Dollar (\$)',
      AppCurrency.gbp =>
        isEnglish ? 'British pound (£)' : 'Britisches Pfund (£)',
      AppCurrency.chf =>
        isEnglish ? 'Swiss franc (CHF)' : 'Schweizer Franken (CHF)',
      AppCurrency.jpy => isEnglish ? 'Japanese yen (¥)' : 'Japanischer Yen (¥)',
    };
  }

  String get steamSync => isEnglish ? 'Steam sync' : 'Steam-Sync';
  String get steamAccountIdentifier =>
      isEnglish ? 'SteamID64 or profile name' : 'SteamID64 oder Profilname';
  String get steamAccountIdentifierHint => isEnglish
      ? '7656119... or custom URL name'
      : '7656119... oder Custom-URL-Name';
  String get steamWebApiKey =>
      isEnglish ? 'Steam Web API key' : 'Steam-Web-API-Key';
  String get showSteamApiKey =>
      isEnglish ? 'Show Steam Web API key' : 'Steam-Web-API-Key anzeigen';
  String get hideSteamApiKey =>
      isEnglish ? 'Hide Steam Web API key' : 'Steam-Web-API-Key ausblenden';
  String get includePlayedFreeGames => isEnglish
      ? 'Include played free games'
      : 'Gespielte Free-to-play-Spiele einschließen';
  String get saveSteamSettings =>
      isEnglish ? 'Save Steam settings' : 'Steam-Einstellungen speichern';
  String get steamSettingsSaved =>
      isEnglish ? 'Steam settings saved.' : 'Steam-Einstellungen gespeichert.';

  String get addPurchaseTitle => isEnglish ? 'Add purchase' : 'Kauf hinzufügen';
  String get editPurchaseTitle =>
      isEnglish ? 'Edit purchase' : 'Kauf bearbeiten';
  String get purchaseDataTab => isEnglish ? 'Purchase data' : 'Kaufdaten';
  String get associatedGame =>
      isEnglish ? 'Associated game' : 'Zugehöriges Spiel';
  String get steamApp => isEnglish ? 'Steam app' : 'Steam-App';
  String get steamAppNotLinked =>
      isEnglish ? 'No Steam app linked' : 'Keine Steam-App verknüpft';
  String steamAppLinked(int appId) {
    return isEnglish
        ? 'Linked Steam app: $appId'
        : 'Verknüpfte Steam-App: $appId';
  }

  String get linkSteamApp =>
      isEnglish ? 'Link Steam app' : 'Steam-App verknüpfen';
  String get clearSteamAppLink =>
      isEnglish ? 'Clear Steam link' : 'Steam-Verknüpfung entfernen';
  String get searchSteamApp =>
      isEnglish ? 'Search Steam app' : 'Steam-App suchen';
  String get steamSearchQuery => isEnglish ? 'Search term' : 'Suchbegriff';
  String get search => isEnglish ? 'Search' : 'Suchen';
  String get noSteamResults =>
      isEnglish ? 'No Steam results found.' : 'Keine Steam-Treffer gefunden.';
  String get gameName => isEnglish ? 'Game name' : 'Spielname';
  String get dlcName => isEnglish ? 'DLC name' : 'DLC-Name';
  String get steamAppIdOptional =>
      isEnglish ? 'Steam App ID optional' : 'Steam-App-ID optional';
  String get editionOptional =>
      isEnglish ? 'Edition optional' : 'Edition optional';
  String purchaseDate(String date) {
    return isEnglish ? 'Purchase date: $date' : 'Kaufdatum: $date';
  }

  String releaseDate(String date) {
    return 'Release: $date';
  }

  String get purchasePrice => isEnglish ? 'Purchase price' : 'Kaufpreis';
  String get originalPriceOptional =>
      isEnglish ? 'Original price optional' : 'Originalpreis optional';
  String get noteOptional => isEnglish ? 'Note optional' : 'Notiz optional';
  String get playtimeOptional =>
      isEnglish ? 'Playtime optional' : 'Spielzeit optional';
  String get gameLengthEstimates =>
      isEnglish ? 'Length estimates' : 'Längenschätzung';
  String get mainStoryHoursOptional =>
      isEnglish ? 'Main story optional' : 'Hauptstory optional';
  String get mainExtraHoursOptional =>
      isEnglish ? 'Main + extras optional' : 'Hauptstory + Extras optional';
  String get completionistHoursOptional =>
      isEnglish ? 'Completionist optional' : 'Komplett optional';
  String get saveChanges => isEnglish ? 'Save changes' : 'Änderungen speichern';
  String get save => isEnglish ? 'Save' : 'Speichern';
  String get enterGameName =>
      isEnglish ? 'Enter a game name' : 'Bitte Spielname eingeben';
  String get enterDlcName =>
      isEnglish ? 'Enter a DLC name' : 'Bitte DLC-Name eingeben';
  String get enterPurchasePrice =>
      isEnglish ? 'Enter a purchase price' : 'Bitte Kaufpreis eingeben';
  String get enterValidNumber =>
      isEnglish ? 'Enter a valid number' : 'Bitte gültige Zahl eingeben';
  String get enterValidSteamAppId => isEnglish
      ? 'Enter a valid positive Steam App ID'
      : 'Bitte gültige positive Steam-App-ID eingeben';
  String get priceCannotBeNegative =>
      isEnglish ? 'Price cannot be negative' : 'Preis darf nicht negativ sein';
  String get originalPriceCannotBeNegative => isEnglish
      ? 'Original price cannot be negative'
      : 'Originalpreis darf nicht negativ sein';
  String get playtimeCannotBeNegative => isEnglish
      ? 'Playtime cannot be negative'
      : 'Spielzeit darf nicht negativ sein';
  String get hoursCannotBeNegative => isEnglish
      ? 'Hours cannot be negative'
      : 'Stunden dürfen nicht negativ sein';

  String sortLabel(String key, String currencySymbol) {
    return switch (key) {
      'dateNewestFirst' =>
        isEnglish ? 'Date: newest first' : 'Datum: neueste zuerst',
      'dateOldestFirst' =>
        isEnglish ? 'Date: oldest first' : 'Datum: älteste zuerst',
      'priceHighestFirst' =>
        isEnglish ? 'Price: highest first' : 'Preis: höchste zuerst',
      'priceLowestFirst' =>
        isEnglish ? 'Price: lowest first' : 'Preis: niedrigste zuerst',
      'nameAZ' => isEnglish ? 'Name: A-Z' : 'Name: A-Z',
      'nameZA' => isEnglish ? 'Name: Z-A' : 'Name: Z-A',
      'discountHighestFirst' =>
        isEnglish ? 'Discount: highest first' : 'Rabatt: höchste zuerst',
      'discountLowestFirst' =>
        isEnglish ? 'Discount: lowest first' : 'Rabatt: niedrigste zuerst',
      'playtimeHighestFirst' =>
        isEnglish ? 'Playtime: highest first' : 'Spielzeit: höchste zuerst',
      'playtimeLowestFirst' =>
        isEnglish ? 'Playtime: lowest first' : 'Spielzeit: niedrigste zuerst',
      'pricePerHourLowestFirst' =>
        isEnglish
            ? '$currencySymbol/h: lowest first'
            : '$currencySymbol/h: niedrigste zuerst',
      'pricePerHourHighestFirst' =>
        isEnglish
            ? '$currencySymbol/h: highest first'
            : '$currencySymbol/h: höchste zuerst',
      _ => key,
    };
  }
}

class AppTextScope extends InheritedWidget {
  final AppStrings strings;

  const AppTextScope({super.key, required this.strings, required super.child});

  @override
  bool updateShouldNotify(AppTextScope oldWidget) {
    return oldWidget.strings.locale != strings.locale;
  }
}
