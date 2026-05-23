import 'package:flutter/material.dart';

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

class AppSettings {
  final AppThemeMode themeMode;
  final AppLanguage language;
  final AppCurrency currency;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.language = AppLanguage.german,
    this.currency = AppCurrency.eur,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    AppCurrency? currency,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      currency: currency ?? this.currency,
    );
  }

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
        other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(themeMode, language, currency);
}
