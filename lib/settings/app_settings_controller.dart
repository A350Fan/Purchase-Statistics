import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

class AppSettingsController extends ChangeNotifier {
  final AppSettingsStore _store;

  AppSettings _settings = const AppSettings();
  bool _isLoaded = false;

  AppSettingsController({AppSettingsStore? store})
    : _store = store ?? SettingsRepository();

  AppSettings get settings => _settings;

  bool get isLoaded => _isLoaded;

  ThemeMode get themeMode => _settings.themeMode.materialThemeMode;

  Locale get locale {
    return _settings.resolveLocale(PlatformDispatcher.instance.locale);
  }

  Future<void> load() async {
    _settings = await _store.loadSettings();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _updateSettings(_settings.copyWith(themeMode: themeMode));
  }

  Future<void> setLanguage(AppLanguage language) async {
    await _updateSettings(_settings.copyWith(language: language));
  }

  Future<void> setCurrency(AppCurrency currency) async {
    await _updateSettings(_settings.copyWith(currency: currency));
  }

  Future<void> setSteamSyncSettings({
    required String? steamAccountIdentifier,
    required String? steamWebApiKey,
    required bool steamIncludePlayedFreeGames,
  }) async {
    await _updateSettings(
      AppSettings(
        themeMode: _settings.themeMode,
        language: _settings.language,
        currency: _settings.currency,
        steamAccountIdentifier: _nullableValue(steamAccountIdentifier),
        steamWebApiKey: _nullableValue(steamWebApiKey),
        steamIncludePlayedFreeGames: steamIncludePlayedFreeGames,
      ),
    );
  }

  Future<void> _updateSettings(AppSettings settings) async {
    if (settings == _settings) {
      return;
    }

    _settings = settings;
    notifyListeners();
    await _store.saveSettings(settings);
  }

  String? _nullableValue(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();

    assert(scope != null, 'No AppSettingsScope found in context.');
    return scope!.notifier!;
  }

  static AppSettingsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
        ?.notifier;
  }
}
