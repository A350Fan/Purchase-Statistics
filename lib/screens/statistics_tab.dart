import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

class StatisticsTab extends StatefulWidget {
  final List<SteamPurchase> purchases;

  const StatisticsTab({super.key, required this.purchases});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final stats = SteamStatistics(widget.purchases);

    if (widget.purchases.isEmpty) {
      return Center(child: Text(strings.noStatisticsData));
    }

    final years = stats.years;
    _selectedYear = _resolveSelectedYear(years, stats.currentDate.year);

    final selectedYear = _selectedYear!;
    final annualRows = stats.annualStatistics;
    final annualSummary = stats.annualSummary;
    final quarterRows = stats.quarterlyStatisticsForYear(selectedYear);
    final quarterSummary = stats.quarterlySummaryForYear(selectedYear);
    final maxAnnualSpending = _maxSpending(
      annualRows.map((row) => row.spending),
    );
    final maxQuarterSpending = _maxSpending(
      quarterRows.map((row) => row.spending),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const annualCardWidth = 830.0;
        const cardSpacing = 16.0;
        const quarterCardMinWidth = 720.0;
        final isWide =
            constraints.maxWidth >=
            annualCardWidth + cardSpacing + quarterCardMinWidth;
        final annualCard = _buildAnnualCard(
          context,
          strings,
          annualRows,
          annualSummary,
          maxAnnualSpending,
          currency,
        );
        final quarterCard = _buildQuarterCard(
          context,
          strings,
          years,
          selectedYear,
          quarterRows,
          quarterSummary,
          maxQuarterSpending,
          currency,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              strings.statisticsTab,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: annualCardWidth, child: annualCard),
                  const SizedBox(width: cardSpacing),
                  Expanded(child: quarterCard),
                ],
              )
            else ...[
              annualCard,
              const SizedBox(height: 16),
              quarterCard,
            ],
          ],
        );
      },
    );
  }

  int _resolveSelectedYear(List<int> years, int preferredYear) {
    final selectedYear = _selectedYear;

    if (selectedYear != null && years.contains(selectedYear)) {
      return selectedYear;
    }

    if (years.contains(preferredYear)) {
      return preferredYear;
    }

    return years.last;
  }

  double _maxSpending(Iterable<double> values) {
    var max = 0.0;

    for (final value in values) {
      if (value > max) {
        max = value;
      }
    }

    return max;
  }

  Widget _buildAnnualCard(
    BuildContext context,
    AppStrings strings,
    List<AnnualStatistics> rows,
    AnnualStatisticsSummary summary,
    double maxSpending,
    AppCurrency currency,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.annualValues,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 760,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(80),
                    1: FixedColumnWidth(130),
                    2: FixedColumnWidth(120),
                    3: FixedColumnWidth(140),
                    4: FixedColumnWidth(140),
                    5: FixedColumnWidth(110),
                  },
                  children: [
                    TableRow(
                      children: [
                        _headerCell(context, strings.year),
                        _headerCell(context, strings.spending),
                        _headerCell(context, strings.averageDiscount),
                        _headerCell(context, strings.cumulative),
                        _headerCell(context, strings.playtime),
                        _headerCell(context, '${currency.symbol}/h'),
                      ],
                    ),
                    ...rows.map((row) {
                      return TableRow(
                        children: [
                          _tableCell(context, row.year.toString()),
                          _tableCell(
                            context,
                            _formatCurrency(
                              row.spending,
                              currency,
                              zeroAsDash: true,
                            ),
                            alignment: Alignment.centerRight,
                            backgroundColor: _spendingColor(
                              row.spending,
                              maxSpending,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatPercent(row.averageDiscount, strings),
                            alignment: Alignment.centerRight,
                            backgroundColor: _discountColor(
                              row.averageDiscount,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatCurrency(row.cumulativeSpending, currency),
                            alignment: Alignment.centerRight,
                          ),
                          _tableCell(
                            context,
                            _formatHours(row.playtimeHours, zeroAsDash: true),
                            alignment: Alignment.centerRight,
                          ),
                          _tableCell(
                            context,
                            _formatPricePerHour(
                              row.pricePerHour,
                              strings,
                              currency,
                            ),
                            alignment: Alignment.centerRight,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            _summaryRow(
              context,
              strings.average,
              _formatCurrency(summary.averageSpending, currency),
              trailing: _formatPercent(summary.averageDiscount, strings),
            ),
            _summaryRow(
              context,
              strings.total,
              _formatCurrency(summary.totalSpending, currency),
            ),
            _summaryRow(
              context,
              strings.totalOriginalPrice,
              _formatCurrency(summary.totalOriginalPrice, currency),
            ),
            _summaryRow(
              context,
              strings.playtime,
              _formatHours(summary.totalPlaytimeHours, zeroAsDash: true),
            ),
            _summaryRow(
              context,
              strings.averagePricePerHour(currency.symbol),
              _formatPricePerHour(summary.pricePerHour, strings, currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarterCard(
    BuildContext context,
    AppStrings strings,
    List<int> years,
    int selectedYear,
    List<QuarterlyStatistics> rows,
    QuarterlyStatisticsSummary summary,
    double maxSpending,
    AppCurrency currency,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.selectYearQuestion,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: selectedYear,
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
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 680,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(90),
                    1: FixedColumnWidth(130),
                    2: FixedColumnWidth(110),
                    3: FixedColumnWidth(140),
                    4: FixedColumnWidth(110),
                    5: FixedColumnWidth(100),
                  },
                  children: [
                    TableRow(
                      children: [
                        _headerCell(context, strings.quarter),
                        _headerCell(context, strings.spending),
                        _headerCell(context, strings.averageDiscount),
                        _headerCell(context, strings.cumulative),
                        _headerCell(context, strings.playtime),
                        _headerCell(context, '${currency.symbol}/h'),
                      ],
                    ),
                    ...rows.map((row) {
                      return TableRow(
                        children: [
                          _tableCell(
                            context,
                            row.quarter.toString(),
                            alignment: Alignment.centerRight,
                          ),
                          _tableCell(
                            context,
                            _formatCurrency(
                              row.spending,
                              currency,
                              zeroAsDash: true,
                            ),
                            alignment: Alignment.centerRight,
                            backgroundColor: _spendingColor(
                              row.spending,
                              maxSpending,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatPercent(row.averageDiscount, strings),
                            alignment: Alignment.centerRight,
                            backgroundColor: _discountColor(
                              row.averageDiscount,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatCurrency(
                              row.cumulativeSpending,
                              currency,
                              zeroAsDash: true,
                            ),
                            alignment: Alignment.centerRight,
                          ),
                          _tableCell(
                            context,
                            _formatHours(row.playtimeHours, zeroAsDash: true),
                            alignment: Alignment.centerRight,
                          ),
                          _tableCell(
                            context,
                            _formatPricePerHour(
                              row.pricePerHour,
                              strings,
                              currency,
                            ),
                            alignment: Alignment.centerRight,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            _summaryRow(
              context,
              summary.isProjected ? strings.projectedAverage : strings.average,
              _formatCurrency(summary.averageQuarterSpending, currency),
              trailing: _formatPercent(summary.averageDiscount, strings),
            ),
            _summaryRow(
              context,
              summary.isProjected ? strings.projectedTotal : strings.total,
              _formatCurrency(summary.projectedSpending, currency),
            ),
            _summaryRow(
              context,
              strings.playtime,
              _formatHours(summary.totalPlaytimeHours, zeroAsDash: true),
            ),
            _summaryRow(
              context,
              strings.averagePricePerHour(currency.symbol),
              _formatPricePerHour(summary.pricePerHour, strings, currency),
            ),
            if (summary.isProjected)
              _summaryRow(
                context,
                strings.soFar,
                _formatCurrency(summary.actualSpending, currency),
              ),
            const SizedBox(height: 12),
            Text(
              strings.runningYearProjection,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              strings.discountDataNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              strings.pricePerHourDataNote(currency.symbol),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(BuildContext context, String value) {
    return _tableCell(
      context,
      value,
      isHeader: true,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  Widget _tableCell(
    BuildContext context,
    String value, {
    Alignment alignment = Alignment.centerLeft,
    Color? backgroundColor,
    bool isHeader = false,
  }) {
    final theme = Theme.of(context);
    final brightness = backgroundColor == null
        ? null
        : ThemeData.estimateBrightnessForColor(backgroundColor);
    final textColor = brightness == Brightness.dark ? Colors.white : null;
    final textStyle =
        (isHeader ? theme.textTheme.labelLarge : theme.textTheme.bodyMedium)
            ?.copyWith(
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            );

    return Container(
      height: 38,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignment == Alignment.centerRight
            ? TextAlign.right
            : TextAlign.left,
        style: textStyle,
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    String? trailing,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
          Text(value, style: theme.textTheme.titleSmall),
          if (trailing != null) ...[
            const SizedBox(width: 24),
            SizedBox(
              width: 72,
              child: Text(
                trailing,
                textAlign: TextAlign.right,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCurrency(
    double value,
    AppCurrency currency, {
    bool zeroAsDash = false,
  }) {
    if (zeroAsDash && value.abs() < 0.005) {
      return '- ${currency.symbol}';
    }

    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}';
  }

  String _formatPercent(double? value, AppStrings strings) {
    if (value == null) {
      return strings.notAvailable;
    }

    return '${(value * 100).round()}%';
  }

  String _formatHours(double value, {bool zeroAsDash = false}) {
    if (zeroAsDash && value <= 0) {
      return '- h';
    }

    final hasFraction = value != value.roundToDouble();
    final formattedValue = value
        .toStringAsFixed(hasFraction ? 1 : 0)
        .replaceAll('.', ',');

    return '$formattedValue h';
  }

  String _formatPricePerHour(
    double? value,
    AppStrings strings,
    AppCurrency currency,
  ) {
    if (value == null) {
      return strings.notAvailable;
    }

    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}/h';
  }

  Color? _spendingColor(double value, double maxSpending) {
    if (value.abs() < 0.005 || maxSpending <= 0) {
      return null;
    }

    final fraction = (value / maxSpending).clamp(0.0, 1.0).toDouble();

    if (fraction < 0.5) {
      return Color.lerp(
        Colors.green.shade700,
        Colors.amber.shade700,
        fraction * 2,
      );
    }

    return Color.lerp(
      Colors.amber.shade700,
      Colors.red.shade500,
      (fraction - 0.5) * 2,
    );
  }

  Color? _discountColor(double? discount) {
    if (discount == null) {
      return null;
    }

    final fraction = discount.clamp(0.0, 1.0).toDouble();

    return Color.lerp(Colors.red.shade500, Colors.green.shade700, fraction);
  }
}
