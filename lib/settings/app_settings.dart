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

class AppSettings {
  final AppThemeMode themeMode;
  final AppLanguage language;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.language = AppLanguage.german,
  });

  AppSettings copyWith({AppThemeMode? themeMode, AppLanguage? language}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
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
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(themeMode, language);
}
