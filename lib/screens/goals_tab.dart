// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../data/steam_goal_repository.dart';
import '../l10n/app_strings.dart';
import '../logic/steam_goals.dart';
import '../models/steam_goal_settings.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

/// Tab fuer persoenliche Ausgaben- und Backlog-Ziele.
class GoalsTab extends StatefulWidget {
  final List<SteamPurchase> purchases;
  final SteamGoalStore goalStore;
  final DateTime? currentDate;

  const GoalsTab({
    super.key,
    required this.purchases,
    required this.goalStore,
    this.currentDate,
  });

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  // Zielwerte werden separat aus dem GoalStore geladen; Kaeufe kommen vom
  // HomeScreen ueber das Widget.
  SteamGoalSettings _goals = const SteamGoalSettings();
  bool _isLoading = true;
  int? _selectedYear;

  DateTime get _currentDate {
    final currentDate = widget.currentDate ?? DateTime.now();

    return DateTime(currentDate.year, currentDate.month, currentDate.day);
  }

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void didUpdateWidget(covariant GoalsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.goalStore != widget.goalStore) {
      _loadGoals();
    }
  }

  Future<void> _loadGoals() async {
    // Der Store ist injizierbar, damit Tests ohne echte SQLite-Datenbank laufen.
    final goals = await widget.goalStore.loadGoals();

    if (!mounted) {
      return;
    }

    setState(() {
      _goals = goals;
      _isLoading = false;
    });
  }

  Future<void> _openGoalsDialog() async {
    // Der Dialog gibt entweder neue Ziele oder null bei Abbruch zurueck.
    final goals = await showDialog<SteamGoalSettings>(
      context: context,
      builder: (context) {
        final currency =
            AppSettingsScope.maybeOf(context)?.settings.currency ??
            AppCurrency.eur;

        return _GoalsDialog(initialGoals: _goals, currency: currency);
      },
    );

    if (goals == null) {
      return;
    }

    await widget.goalStore.saveGoals(goals);

    if (!mounted) {
      return;
    }

    setState(() {
      _goals = goals;
    });
  }

  List<int> _availableYears() {
    // Ziele koennen fuer vorhandene Kaufjahre und mindestens fuer das aktuelle
    // Jahr betrachtet werden.
    final years = widget.purchases.map((purchase) => purchase.year).toSet()
      ..add(_currentDate.year);
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));

    return sortedYears;
  }

  int _resolveSelectedYear(List<int> years) {
    final selectedYear = _selectedYear;

    if (selectedYear != null && years.contains(selectedYear)) {
      return selectedYear;
    }

    if (years.contains(_currentDate.year)) {
      return _currentDate.year;
    }

    return years.first;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final years = _availableYears();
    final selectedYear = _resolveSelectedYear(years);
    final overview = SteamGoalsOverview(
      purchases: widget.purchases,
      settings: _goals,
      year: selectedYear,
      currentDate: _currentDate,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(strings),
        const SizedBox(height: 16),
        _buildYearPicker(strings, years, selectedYear),
        const SizedBox(height: 16),
        _buildGoalCards(context, strings, currency, overview),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget _buildHeader(AppStrings strings) {
    // Kopfbereich mit kurzer Statuskarte und Button zum Bearbeiten der Ziele.
    final title = Text(
      strings.goalsTab,
      style: Theme.of(context).textTheme.headlineMedium,
    );
    final editButton = FilledButton.icon(
      onPressed: _openGoalsDialog,
      icon: const Icon(Icons.edit),
      label: Text(strings.editGoals),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 12), editButton],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            editButton,
          ],
        );
      },
    );
  }

  Widget _buildYearPicker(AppStrings strings, List<int> years, int year) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(strings.year, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: year,
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedYear = value;
              });
            },
            items: years.map((year) {
              return DropdownMenuItem(
                value: year,
                child: Text(year.toString()),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCards(
    BuildContext context,
    AppStrings strings,
    AppCurrency currency,
    SteamGoalsOverview overview,
  ) {
    // Alle Zielkarten werden aus demselben `SteamGoalsOverview` gebaut, damit
    // die UI keine Berechnungslogik dupliziert.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - (columnCount - 1) * 12) / columnCount;

        final cards = [
          _GoalProgressCard(
            icon: Icons.account_balance_wallet,
            title: strings.annualSpendingGoal,
            value: _formatCurrency(overview.annualSpending, currency),
            target: _formatTarget(
              strings,
              overview.annualSpendingGoal,
              _formatCurrencyNullable(
                overview.annualSpendingGoal.targetValue,
                currency,
              ),
            ),
            projection: overview.projectedAnnualSpending == null
                ? null
                : strings.goalProjection(
                    _formatCurrency(
                      overview.projectedAnnualSpending!,
                      currency,
                    ),
                  ),
            result: overview.annualSpendingGoal,
          ),
          _GoalProgressCard(
            icon: Icons.inventory_2,
            title: strings.backlogLimitGoal,
            value: overview.backlogCount.toString(),
            target: _formatTarget(
              strings,
              overview.backlogGoal,
              _formatCountNullable(overview.backlogGoal.targetValue),
            ),
            result: overview.backlogGoal,
          ),
          _GoalProgressCard(
            icon: Icons.hourglass_empty,
            title: strings.unplayedBacklogGoal,
            value: overview.unplayedBacklogCount.toString(),
            target: _formatTarget(
              strings,
              overview.unplayedBacklogGoal,
              _formatCountNullable(overview.unplayedBacklogGoal.targetValue),
            ),
            result: overview.unplayedBacklogGoal,
          ),
          _GoalProgressCard(
            icon: Icons.savings,
            title: strings.unplayedBacklogValueGoal,
            value: _formatCurrency(overview.unplayedBacklogValue, currency),
            target: _formatTarget(
              strings,
              overview.unplayedBacklogValueGoal,
              _formatCurrencyNullable(
                overview.unplayedBacklogValueGoal.targetValue,
                currency,
              ),
            ),
            result: overview.unplayedBacklogValueGoal,
          ),
          _GoalProgressCard(
            icon: Icons.emoji_events,
            title: strings.completionRateGoal,
            value: _formatPercent(overview.completionRate),
            target: _formatTarget(
              strings,
              overview.completionRateGoal,
              _formatPercent(overview.completionRateGoal.targetValue),
            ),
            result: overview.completionRateGoal,
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((card) {
            return SizedBox(width: cardWidth, child: card);
          }).toList(),
        );
      },
    );
  }

  String _formatTarget(
    AppStrings strings,
    SteamGoalResult result,
    String? value,
  ) {
    if (value == null) {
      return strings.goalNotSet;
    }

    final operator = result.direction == SteamGoalDirection.maximum
        ? '<='
        : '>=';

    return strings.goalTarget('$operator $value');
  }

  String _formatCurrency(double value, AppCurrency currency) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}';
  }

  String? _formatCurrencyNullable(double? value, AppCurrency currency) {
    if (value == null) {
      return null;
    }

    return _formatCurrency(value, currency);
  }

  String? _formatCountNullable(double? value) {
    if (value == null) {
      return null;
    }

    return value.round().toString();
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '-';
    }

    return '${(value * 100).round()} %';
  }
}

/// Einzelne Karte mit Istwert, optionaler Projektion und Zielstatus.
class _GoalProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String target;
  final String? projection;
  final SteamGoalResult result;

  const _GoalProgressCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.target,
    required this.result,
    this.projection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = result.progress?.clamp(0.0, 1.0).toDouble();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _GoalStateChip(state: result.state),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (projection != null) ...[
              const SizedBox(height: 2),
              Text(
                projection!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}

/// Farbiger Statuschip fuer ein Ziel.
class _GoalStateChip extends StatelessWidget {
  final SteamGoalState state;

  const _GoalStateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = switch (state) {
      SteamGoalState.unset => strings.goalStateUnset,
      SteamGoalState.onTrack => strings.goalStateOnTrack,
      SteamGoalState.atRisk => strings.goalStateAtRisk,
      SteamGoalState.offTrack => strings.goalStateOffTrack,
    };
    final color = switch (state) {
      SteamGoalState.unset => colorScheme.onSurfaceVariant,
      SteamGoalState.onTrack => Colors.green,
      SteamGoalState.atRisk => Colors.amber,
      SteamGoalState.offTrack => colorScheme.error,
    };

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withAlpha(32),
      side: BorderSide(color: color.withAlpha(100)),
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: color),
    );
  }
}

/// Dialog zum Bearbeiten aller Zielwerte.
class _GoalsDialog extends StatefulWidget {
  final SteamGoalSettings initialGoals;
  final AppCurrency currency;

  const _GoalsDialog({required this.initialGoals, required this.currency});

  @override
  State<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends State<_GoalsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _annualSpendingController = TextEditingController();
  final _backlogLimitController = TextEditingController();
  final _unplayedBacklogLimitController = TextEditingController();
  final _unplayedBacklogValueController = TextEditingController();
  final _completionRateController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final goals = widget.initialGoals;
    _annualSpendingController.text = _formatDecimal(goals.annualSpendingLimit);
    _backlogLimitController.text = _formatInt(goals.backlogLimit);
    _unplayedBacklogLimitController.text = _formatInt(
      goals.unplayedBacklogLimit,
    );
    _unplayedBacklogValueController.text = _formatDecimal(
      goals.unplayedBacklogValueLimit,
    );
    _completionRateController.text = _formatPercent(goals.completionRateTarget);
  }

  @override
  void dispose() {
    _annualSpendingController.dispose();
    _backlogLimitController.dispose();
    _unplayedBacklogLimitController.dispose();
    _unplayedBacklogValueController.dispose();
    _completionRateController.dispose();
    super.dispose();
  }

  void _save() {
    // Prozentwerte werden intern als Anteil gespeichert, in der UI aber als
    // Prozent angezeigt.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final completionRatePercent = _parseDecimal(_completionRateController.text);

    Navigator.of(context).pop(
      SteamGoalSettings(
        annualSpendingLimit: _parseDecimal(_annualSpendingController.text),
        backlogLimit: _parseInt(_backlogLimitController.text),
        unplayedBacklogLimit: _parseInt(_unplayedBacklogLimitController.text),
        unplayedBacklogValueLimit: _parseDecimal(
          _unplayedBacklogValueController.text,
        ),
        completionRateTarget: completionRatePercent == null
            ? null
            : completionRatePercent / 100,
      ),
    );
  }

  String _formatDecimal(double? value) {
    if (value == null) {
      return '';
    }

    final hasFraction = value != value.roundToDouble();

    return value.toStringAsFixed(hasFraction ? 2 : 0).replaceAll('.', ',');
  }

  String _formatInt(int? value) {
    return value?.toString() ?? '';
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '';
    }

    final percent = value * 100;
    final hasFraction = percent != percent.roundToDouble();

    return percent.toStringAsFixed(hasFraction ? 1 : 0).replaceAll('.', ',');
  }

  double? _parseDecimal(String value) {
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  int? _parseInt(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return int.tryParse(normalized);
  }

  String? _validateDecimal(String? value) {
    final strings = AppStrings.of(context);
    final input = value ?? '';
    final parsedValue = _parseDecimal(input);

    if (input.trim().isNotEmpty && parsedValue == null) {
      return strings.enterValidNumber;
    }

    if (parsedValue != null && parsedValue < 0) {
      return strings.valueCannotBeNegative;
    }

    return null;
  }

  String? _validateInt(String? value) {
    final strings = AppStrings.of(context);
    final input = value ?? '';
    final parsedValue = _parseInt(input);

    if (input.trim().isNotEmpty && parsedValue == null) {
      return strings.enterValidNumber;
    }

    if (parsedValue != null && parsedValue < 0) {
      return strings.valueCannotBeNegative;
    }

    return null;
  }

  String? _validatePercent(String? value) {
    final decimalError = _validateDecimal(value);

    if (decimalError != null) {
      return decimalError;
    }

    final parsedValue = _parseDecimal(value ?? '');

    if (parsedValue != null && parsedValue > 100) {
      return AppStrings.of(context).percentOutOfRange;
    }

    return null;
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String? Function(String? value) validator,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AlertDialog(
      title: Text(strings.editGoals),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNumberField(
                  controller: _annualSpendingController,
                  label: strings.annualSpendingLimitOptional,
                  suffix: widget.currency.symbol,
                  validator: _validateDecimal,
                ),
                const SizedBox(height: 16),
                _buildNumberField(
                  controller: _backlogLimitController,
                  label: strings.backlogLimitOptional,
                  validator: _validateInt,
                ),
                const SizedBox(height: 16),
                _buildNumberField(
                  controller: _unplayedBacklogLimitController,
                  label: strings.unplayedBacklogLimitOptional,
                  validator: _validateInt,
                ),
                const SizedBox(height: 16),
                _buildNumberField(
                  controller: _unplayedBacklogValueController,
                  label: strings.unplayedBacklogValueLimitOptional,
                  suffix: widget.currency.symbol,
                  validator: _validateDecimal,
                ),
                const SizedBox(height: 16),
                _buildNumberField(
                  controller: _completionRateController,
                  label: strings.completionRateTargetOptional,
                  suffix: '%',
                  validator: _validatePercent,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: Text(strings.save),
        ),
      ],
    );
  }
}
