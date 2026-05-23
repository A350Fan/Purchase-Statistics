import 'package:flutter/widgets.dart';

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
  String get totalSpent => isEnglish ? 'Total spent' : 'Gesamtausgaben';
  String get averageDiscount => isEnglish ? 'Avg. discount' : 'Ø Rabatt';
  String get playtime => isEnglish ? 'Playtime' : 'Spielzeit';
  String averagePricePerHour(String currencySymbol) {
    return isEnglish ? 'Avg. $currencySymbol/h' : 'Ø $currencySymbol/h';
  }

  String get overviewTab => isEnglish ? 'Overview' : 'Übersicht';
  String get statisticsTab => isEnglish ? 'Statistics' : 'Statistik';
  String get chartsTab => isEnglish ? 'Charts' : 'Diagramme';
  String get collectionsTab => isEnglish ? 'Collections' : 'Kollektionen';
  String get purchaseFab => isEnglish ? 'Purchase' : 'Kauf';
  String get collectionFab => isEnglish ? 'Collection' : 'Kollektion';
  String get importCsv => isEnglish ? 'Import CSV' : 'CSV importieren';
  String get exportCsv => isEnglish ? 'Export CSV' : 'CSV exportieren';
  String get openSettings => isEnglish ? 'Settings' : 'Einstellungen';
  String get edit => isEnglish ? 'Edit' : 'Bearbeiten';
  String get delete => isEnglish ? 'Delete' : 'Löschen';
  String get noPurchases => isEnglish
      ? 'No purchases yet. Add your first Steam purchase.'
      : 'Noch keine Käufe vorhanden. Füge deinen ersten Steam-Kauf hinzu.';
  String get noStatisticsData => isEnglish
      ? 'No statistics data yet.'
      : 'Noch keine Statistikdaten vorhanden.';
  String get noChartData =>
      isEnglish ? 'No chart data yet.' : 'Noch keine Diagrammdaten vorhanden.';
  String get noCollections => isEnglish
      ? 'No collections yet. Create your first collection.'
      : 'Noch keine Kollektionen vorhanden. Erstelle deine erste Kollektion.';
  String get noCollectionItems => isEnglish
      ? 'No purchases in this collection yet.'
      : 'Noch keine Käufe in dieser Kollektion.';
  String get noData => isEnglish ? 'No data' : 'Keine Daten';
  String get price => isEnglish ? 'Price' : 'Preis';
  String get discount => isEnglish ? 'Discount' : 'Rabatt';
  String get cost => isEnglish ? 'Cost' : 'Kosten';
  String get game => isEnglish ? 'Game' : 'Spiel';
  String get dlc => 'DLC';
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
  String get collectionName => isEnglish ? 'Name' : 'Name';
  String get collectionDescriptionOptional =>
      isEnglish ? 'Description optional' : 'Beschreibung optional';
  String get enterCollectionName =>
      isEnglish ? 'Enter a collection name' : 'Bitte Namen eingeben';
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
  String get addPurchaseToCollection =>
      isEnglish ? 'Add purchase' : 'Kauf hinzufügen';
  String get selectPurchaseForCollection =>
      isEnglish ? 'Select purchase' : 'Kauf auswählen';
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

  String get addPurchaseTitle => isEnglish ? 'Add purchase' : 'Kauf hinzufügen';
  String get editPurchaseTitle =>
      isEnglish ? 'Edit purchase' : 'Kauf bearbeiten';
  String get purchaseDataTab => isEnglish ? 'Purchase data' : 'Kaufdaten';
  String get associatedGame =>
      isEnglish ? 'Associated game' : 'Zugehöriges Spiel';
  String get gameName => isEnglish ? 'Game name' : 'Spielname';
  String get dlcName => isEnglish ? 'DLC name' : 'DLC-Name';
  String get editionOptional =>
      isEnglish ? 'Edition optional' : 'Edition optional';
  String purchaseDate(String date) {
    return isEnglish ? 'Purchase date: $date' : 'Kaufdatum: $date';
  }

  String get purchasePrice => isEnglish ? 'Purchase price' : 'Kaufpreis';
  String get originalPriceOptional =>
      isEnglish ? 'Original price optional' : 'Originalpreis optional';
  String get noteOptional => isEnglish ? 'Note optional' : 'Notiz optional';
  String get playtimeOptional =>
      isEnglish ? 'Playtime optional' : 'Spielzeit optional';
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
  String get priceCannotBeNegative =>
      isEnglish ? 'Price cannot be negative' : 'Preis darf nicht negativ sein';
  String get originalPriceMustBePositive => isEnglish
      ? 'Original price must be greater than 0'
      : 'Originalpreis muss größer als 0 sein';
  String get playtimeCannotBeNegative => isEnglish
      ? 'Playtime cannot be negative'
      : 'Spielzeit darf nicht negativ sein';

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
