import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

/// Einstellungsseite fuer Darstellung, Sprache, Waehrung, Steam-Sync und
/// Lizenzinformationen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controller fuer die Steam-Sync-Formularfelder. Theme/Sprache/Waehrung
  // werden direkt ueber den AppSettingsController gesetzt.
  final _steamAccountController = TextEditingController();
  final _steamApiKeyController = TextEditingController();

  bool _includePlayedFreeGames = true;
  bool _showSteamApiKey = false;
  bool _hasLoadedSteamSettings = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Die gespeicherten Steam-Felder werden erst geladen, wenn der
    // AppSettingsController im Kontext verfuegbar ist.
    if (_hasLoadedSteamSettings) {
      return;
    }

    final settings = AppSettingsScope.of(context).settings;
    _steamAccountController.text = settings.steamAccountIdentifier ?? '';
    _steamApiKeyController.text = settings.steamWebApiKey ?? '';
    _includePlayedFreeGames = settings.steamIncludePlayedFreeGames;
    _hasLoadedSteamSettings = true;
  }

  @override
  void dispose() {
    _steamAccountController.dispose();
    _steamApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final controller = AppSettingsScope.of(context);
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsSection(
              title: strings.appearance,
              icon: Icons.contrast,
              child: SegmentedButton<AppThemeMode>(
                segments: [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    icon: const Icon(Icons.brightness_auto),
                    label: Text(strings.system),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(strings.light),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(strings.dark),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  controller.setThemeMode(selection.single);
                },
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: strings.language,
              icon: Icons.language,
              child: SegmentedButton<AppLanguage>(
                segments: [
                  ButtonSegment(
                    value: AppLanguage.system,
                    icon: const Icon(Icons.public),
                    label: Text(strings.system),
                  ),
                  ButtonSegment(
                    value: AppLanguage.german,
                    label: Text(strings.german),
                  ),
                  ButtonSegment(
                    value: AppLanguage.english,
                    label: Text(strings.english),
                  ),
                ],
                selected: {settings.language},
                onSelectionChanged: (selection) {
                  controller.setLanguage(selection.single);
                },
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: strings.currency,
              icon: Icons.payments,
              child: DropdownButtonFormField<AppCurrency>(
                initialValue: settings.currency,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: AppCurrency.values.map((currency) {
                  return DropdownMenuItem(
                    value: currency,
                    child: Text(strings.currencyLabel(currency)),
                  );
                }).toList(),
                onChanged: (currency) {
                  if (currency == null) {
                    return;
                  }

                  controller.setCurrency(currency);
                },
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: strings.steamSync,
              icon: Icons.sports_esports,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _steamAccountController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: strings.steamAccountIdentifier,
                      hintText: strings.steamAccountIdentifierHint,
                      prefixIcon: const Icon(Icons.person),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _steamApiKeyController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: strings.steamWebApiKey,
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        tooltip: _showSteamApiKey
                            ? strings.hideSteamApiKey
                            : strings.showSteamApiKey,
                        onPressed: () {
                          setState(() {
                            _showSteamApiKey = !_showSteamApiKey;
                          });
                        },
                        icon: Icon(
                          _showSteamApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    obscureText: !_showSteamApiKey,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveSteamSettings(strings),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.includePlayedFreeGames),
                    value: _includePlayedFreeGames,
                    onChanged: (value) {
                      setState(() {
                        _includePlayedFreeGames = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _saveSteamSettings(strings),
                      icon: const Icon(Icons.save),
                      label: Text(strings.saveSteamSettings),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: strings.legal,
              icon: Icons.balance,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(strings.openSourceLicenses),
                subtitle: Text(strings.openSourceLicensesDescription),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: strings.appTitle,
                    applicationLegalese: strings.applicationLegalese,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Speichert nur die Steam-Sync-Einstellungen.
  ///
  /// Die anderen Einstellungen werden schon beim Auswaehlen gespeichert.
  Future<void> _saveSteamSettings(AppStrings strings) async {
    final controller = AppSettingsScope.of(context);

    try {
      await controller.setSteamSyncSettings(
        steamAccountIdentifier: _steamAccountController.text,
        steamWebApiKey: _steamApiKeyController.text,
        steamIncludePlayedFreeGames: _includePlayedFreeGames,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.steamSettingsSaveFailed)),
        );
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(strings.steamSettingsSaved)));
  }
}

/// Wiederverwendeter Abschnitt mit Titel und eingeruecktem Inhalt.
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
