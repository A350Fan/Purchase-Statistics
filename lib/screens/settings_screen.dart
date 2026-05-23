import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          ],
        ),
      ),
    );
  }
}

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
