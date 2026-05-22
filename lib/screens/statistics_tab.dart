import 'package:flutter/material.dart';

import '../logic/steam_statistics.dart';
import '../models/steam_purchase.dart';
import '../widgets/stat_bar.dart';

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
    final years = stats.spendingByYear.keys.toList()..sort();

    if (widget.purchases.isEmpty) {
      return const Center(child: Text('Noch keine Statistikdaten vorhanden.'));
    }

    _selectedYear ??= years.last;

    final maxYearSpending = stats.spendingByYear.values.reduce(
      (current, next) => next > current ? next : current,
    );

    final quarterSpending = stats.spendingByQuarterForYear(_selectedYear!);
    final maxQuarterSpending = quarterSpending.values.reduce(
      (current, next) => next > current ? next : current,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Statistik', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ausgaben pro Jahr',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ...years.map((year) {
                  final spending = stats.spendingByYear[year] ?? 0.0;

                  return StatBar(
                    label: year.toString(),
                    value: '${spending.toStringAsFixed(2)} €',
                    fraction: maxYearSpending == 0
                        ? 0
                        : spending / maxYearSpending,
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quartale',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    DropdownButton<int>(
                      value: _selectedYear,
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
                ...quarterSpending.entries.map((entry) {
                  final quarter = entry.key;
                  final spending = entry.value;

                  return StatBar(
                    label: 'Q$quarter',
                    value: '${spending.toStringAsFixed(2)} €',
                    fraction: maxQuarterSpending == 0
                        ? 0
                        : spending / maxQuarterSpending,
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
