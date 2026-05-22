import 'package:flutter/material.dart';

import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';

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
    final stats = SteamStatistics(widget.purchases);

    if (widget.purchases.isEmpty) {
      return const Center(child: Text('Noch keine Statistikdaten vorhanden.'));
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
        final isWide = constraints.maxWidth >= 1000;
        final annualCard = _buildAnnualCard(
          context,
          annualRows,
          annualSummary,
          maxAnnualSpending,
        );
        final quarterCard = _buildQuarterCard(
          context,
          years,
          selectedYear,
          quarterRows,
          quarterSummary,
          maxQuarterSpending,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Statistik',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: annualCard),
                  const SizedBox(width: 16),
                  SizedBox(width: 520, child: quarterCard),
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
    List<AnnualStatistics> rows,
    AnnualStatisticsSummary summary,
    double maxSpending,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jahreswerte', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 650,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(80),
                    1: FixedColumnWidth(130),
                    2: FixedColumnWidth(120),
                    3: FixedColumnWidth(140),
                    4: FixedColumnWidth(120),
                  },
                  children: [
                    TableRow(
                      children: [
                        _headerCell(context, 'Jahr'),
                        _headerCell(context, 'Ausgaben'),
                        _headerCell(context, 'Ø Rabatt'),
                        _headerCell(context, 'Kumulativ'),
                        _headerCell(context, '€/h'),
                      ],
                    ),
                    ...rows.map((row) {
                      return TableRow(
                        children: [
                          _tableCell(context, row.year.toString()),
                          _tableCell(
                            context,
                            _formatCurrency(row.spending, zeroAsDash: true),
                            alignment: Alignment.centerRight,
                            backgroundColor: _spendingColor(
                              row.spending,
                              maxSpending,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatPercent(row.averageDiscount),
                            alignment: Alignment.centerRight,
                            backgroundColor: _discountColor(
                              row.averageDiscount,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatCurrency(row.cumulativeSpending),
                            alignment: Alignment.centerRight,
                          ),
                          _tableCell(
                            context,
                            'N/V',
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
              'Mittelwert',
              _formatCurrency(summary.averageSpending),
              trailing: _formatPercent(summary.averageDiscount),
            ),
            _summaryRow(
              context,
              'Summe',
              _formatCurrency(summary.totalSpending),
            ),
            _summaryRow(
              context,
              'Summe UVP',
              _formatCurrency(summary.totalOriginalPrice),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarterCard(
    BuildContext context,
    List<int> years,
    int selectedYear,
    List<QuarterlyStatistics> rows,
    QuarterlyStatisticsSummary summary,
    double maxSpending,
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
                    'Welches Jahr soll ausgewertet werden?',
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
                width: 470,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(90),
                    1: FixedColumnWidth(130),
                    2: FixedColumnWidth(110),
                    3: FixedColumnWidth(140),
                  },
                  children: [
                    TableRow(
                      children: [
                        _headerCell(context, 'Quartal'),
                        _headerCell(context, 'Ausgaben'),
                        _headerCell(context, 'Ø Rabatt'),
                        _headerCell(context, 'Kumulativ'),
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
                            _formatCurrency(row.spending, zeroAsDash: true),
                            alignment: Alignment.centerRight,
                            backgroundColor: _spendingColor(
                              row.spending,
                              maxSpending,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatPercent(row.averageDiscount),
                            alignment: Alignment.centerRight,
                            backgroundColor: _discountColor(
                              row.averageDiscount,
                            ),
                          ),
                          _tableCell(
                            context,
                            _formatCurrency(
                              row.cumulativeSpending,
                              zeroAsDash: true,
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
              summary.isProjected ? 'Mittelwert*' : 'Mittelwert',
              _formatCurrency(summary.averageQuarterSpending),
              trailing: _formatPercent(summary.averageDiscount),
            ),
            _summaryRow(
              context,
              summary.isProjected ? 'Summe*' : 'Summe',
              _formatCurrency(summary.projectedSpending),
            ),
            if (summary.isProjected)
              _summaryRow(
                context,
                'Bisher',
                _formatCurrency(summary.actualSpending),
              ),
            const SizedBox(height: 12),
            Text(
              '* laufendes Jahr wird hochgerechnet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Ø Rabatt: nur Spiele mit bekanntem UVP',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '€/h: benötigt gespeicherte Spielzeit',
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

  String _formatCurrency(double value, {bool zeroAsDash = false}) {
    if (zeroAsDash && value.abs() < 0.005) {
      return '- €';
    }

    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return 'N/V';
    }

    return '${(value * 100).round()}%';
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
