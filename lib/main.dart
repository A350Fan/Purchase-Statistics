import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/steam_collection_repository.dart';
import 'data/steam_purchase_repository.dart';
import 'l10n/app_strings.dart';
import 'screens/home_screen.dart';
import 'settings/app_settings_controller.dart';

void main() {
  runApp(const SteamStatsApp());
}

class SteamStatsApp extends StatefulWidget {
  final AppSettingsController? settingsController;
  final SteamPurchaseRepository? purchaseRepository;
  final SteamCollectionRepository? collectionRepository;

  const SteamStatsApp({
    super.key,
    this.settingsController,
    this.purchaseRepository,
    this.collectionRepository,
  });

  @override
  State<SteamStatsApp> createState() => _SteamStatsAppState();
}

class _SteamStatsAppState extends State<SteamStatsApp> {
  static final ThemeData _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF6F8FA),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF6F8FA),
      foregroundColor: Color(0xFF16202A),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    useMaterial3: true,
  );

  static final ThemeData _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF101418),
    cardTheme: const CardThemeData(
      color: Color(0xFF1A2027),
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101418),
      foregroundColor: Color(0xFFE7ECEF),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF151B21),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A2027)),
    useMaterial3: true,
  );

  late final AppSettingsController _settingsController;
  late final bool _ownsSettingsController;

  @override
  void initState() {
    super.initState();

    _settingsController = widget.settingsController ?? AppSettingsController();
    _ownsSettingsController = widget.settingsController == null;
    _settingsController.load();
  }

  @override
  void dispose() {
    if (_ownsSettingsController) {
      _settingsController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: _settingsController,
      child: AnimatedBuilder(
        animation: _settingsController,
        builder: (context, _) {
          final strings = AppStrings.forLocale(_settingsController.locale);

          return AppTextScope(
            strings: strings,
            child: MaterialApp(
              title: strings.appTitle,
              debugShowCheckedModeBanner: false,
              locale: strings.locale,
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              themeMode: _settingsController.themeMode,
              theme: _lightTheme,
              darkTheme: _darkTheme,
              home: HomeScreen(
                repository: widget.purchaseRepository,
                collectionRepository: widget.collectionRepository,
              ),
            ),
          );
        },
      ),
    );
  }
}
