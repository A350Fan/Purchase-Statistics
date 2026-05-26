import 'package:flutter/material.dart';

/// App-eigener Theme-Modus.
///
/// Diese Enum trennt die gespeicherte Einstellung von Flutters `ThemeMode` und
/// kapselt die Umrechnung an einer Stelle.
enum AppThemeMode {
  system,
  light,
  dark;

  String get storageValue {
    return switch (this) {
      AppThemeMode.system => 'system',
      AppThemeMode.light => 'light',
      AppThemeMode.dark => 'dark',
    };
  }

  ThemeMode get materialThemeMode {
    return switch (this) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }

  static AppThemeMode fromStorage(Object? value) {
    return switch (value?.toString()) {
      'system' => AppThemeMode.system,
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.dark,
    };
  }
}

/// Sprachauswahl der App.
///
/// `system` folgt der Plattformsprache, alle anderen Werte erzwingen eine
/// konkrete Locale.
enum AppLanguage {
  system,
  german,
  english;

  String get storageValue {
    return switch (this) {
      AppLanguage.system => 'system',
      AppLanguage.german => 'de',
      AppLanguage.english => 'en',
    };
  }

  static AppLanguage fromStorage(Object? value) {
    return switch (value?.toString()) {
      'system' => AppLanguage.system,
      'de' => AppLanguage.german,
      'en' => AppLanguage.english,
      _ => AppLanguage.german,
    };
  }
}

/// Waehrungen, in denen Preise angezeigt werden koennen.
enum AppCurrency {
  eur,
  usd,
  gbp,
  chf,
  jpy;

  String get storageValue {
    return switch (this) {
      AppCurrency.eur => 'eur',
      AppCurrency.usd => 'usd',
      AppCurrency.gbp => 'gbp',
      AppCurrency.chf => 'chf',
      AppCurrency.jpy => 'jpy',
    };
  }

  String get symbol {
    return switch (this) {
      AppCurrency.eur => '€',
      AppCurrency.usd => r'$',
      AppCurrency.gbp => '£',
      AppCurrency.chf => 'CHF',
      AppCurrency.jpy => '¥',
    };
  }

  static AppCurrency fromStorage(Object? value) {
    return switch (value?.toString()) {
      'eur' => AppCurrency.eur,
      'usd' => AppCurrency.usd,
      'gbp' => AppCurrency.gbp,
      'chf' => AppCurrency.chf,
      'jpy' => AppCurrency.jpy,
      _ => AppCurrency.eur,
    };
  }
}

/// Alle benutzerbezogenen App-Einstellungen.
///
/// Die Steam-Web-API-Daten werden zwar zusammen mit den Settings im UI
/// verwaltet, der geheime API-Key wird vom Repository aber in den Secure
/// Storage ausgelagert.
class AppSettings {
  final AppThemeMode themeMode;
  final AppLanguage language;
  final AppCurrency currency;
  final String? steamAccountIdentifier;
  final String? steamWebApiKey;
  final bool steamIncludePlayedFreeGames;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.language = AppLanguage.german,
    this.currency = AppCurrency.eur,
    this.steamAccountIdentifier,
    this.steamWebApiKey,
    this.steamIncludePlayedFreeGames = true,
  });

  /// Erstellt eine geaenderte Kopie der Einstellungen.
  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    AppCurrency? currency,
    String? steamAccountIdentifier,
    String? steamWebApiKey,
    bool? steamIncludePlayedFreeGames,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      steamAccountIdentifier:
          steamAccountIdentifier ?? this.steamAccountIdentifier,
      steamWebApiKey: steamWebApiKey ?? this.steamWebApiKey,
      steamIncludePlayedFreeGames:
          steamIncludePlayedFreeGames ?? this.steamIncludePlayedFreeGames,
    );
  }

  /// Gibt an, ob beide benoetigten Werte fuer Steam-Sync vorhanden sind.
  bool get hasSteamSyncCredentials {
    return _hasValue(steamAccountIdentifier) && _hasValue(steamWebApiKey);
  }

  /// Bestimmt die tatsaechliche Locale, die MaterialApp verwenden soll.
  Locale resolveLocale(Locale platformLocale) {
    return switch (language) {
      AppLanguage.german => const Locale('de'),
      AppLanguage.english => const Locale('en'),
      AppLanguage.system =>
        platformLocale.languageCode == 'de'
            ? const Locale('de')
            : const Locale('en'),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.language == language &&
        other.currency == currency &&
        other.steamAccountIdentifier == steamAccountIdentifier &&
        other.steamWebApiKey == steamWebApiKey &&
        other.steamIncludePlayedFreeGames == steamIncludePlayedFreeGames;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    language,
    currency,
    steamAccountIdentifier,
    steamWebApiKey,
    steamIncludePlayedFreeGames,
  );

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
