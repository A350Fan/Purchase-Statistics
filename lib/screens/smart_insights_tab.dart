import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../logic/steam_insights.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';
import '../widgets/stat_card.dart';

class SmartInsightsTab extends StatelessWidget {
  final List<SteamPurchase> purchases;
  final ValueChanged<SteamPurchase>? onPurchaseTap;

  const SmartInsightsTab({
    super.key,
    required this.purchases,
    this.onPurchaseTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;

    if (purchases.isEmpty) {
      return Center(child: Text(strings.noInsightsData));
    }

    final insights = SteamInsights(purchases);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.smartInsightsTab,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        _buildSummaryGrid(context, strings, currency, insights),
        const SizedBox(height: 24),
        _buildInsightSection(
          context: context,
          strings: strings,
          currency: currency,
          icon: Icons.flag,
          title: strings.backlogPriority,
          description: strings.backlogPriorityDescription,
          items: insights.backlogPriority,
          showPriority: true,
        ),
        const SizedBox(height: 24),
        _buildInsightSection(
          context: context,
          strings: strings,
          currency: currency,
          icon: Icons.money_off,
          title: strings.expensiveUnplayedGames,
          items: insights.expensiveUnplayedGames,
        ),
        const SizedBox(height: 24),
        _buildInsightSection(
          context: context,
          strings: strings,
          currency: currency,
          icon: Icons.play_circle,
          title: strings.startedBacklogGames,
          items: insights.startedBacklog,
        ),
        const SizedBox(height: 24),
        _buildInsightSection(
          context: context,
          strings: strings,
          currency: currency,
          icon: Icons.trending_up,
          title: strings.highCostPerHourGames,
          items: insights.highCostPerHourGames,
        ),
        const SizedBox(height: 24),
        _buildInsightSection(
          context: context,
          strings: strings,
          currency: currency,
          icon: Icons.remove_circle_outline,
          title: strings.abandonedSpend,
          items: insights.abandonedSpend,
        ),
        const SizedBox(height: 24),
        _buildInsightSection(
          context: context,
          strings: strings,
          currency: currency,
          icon: Icons.fact_check,
          title: strings.statusReviewGames,
          description: strings.statusReviewDescription,
          items: insights.statusReviewGames.map((purchase) {
            return SteamPurchaseInsight(
              purchase: purchase,
              totalPrice: insights.priceIncludingLinkedDlcsForPurchase(
                purchase,
              ),
              playtimeHours: insights.playtimeForPurchase(purchase),
              pricePerHour: insights.pricePerHourForPurchase(purchase),
              score: 0,
              reasons: const [
                SteamInsightReason.missingStatus,
                SteamInsightReason.wellPlayed,
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget _buildSummaryGrid(
    BuildContext context,
    AppStrings strings,
    AppCurrency currency,
    SteamInsights insights,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final crossAxisCount = constraints.maxWidth > 1200
            ? 5
            : isWide
            ? 3
            : 2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.4 : 1.9,
          children: [
            StatCard(
              title: strings.backlog,
              value: insights.backlogGames.length.toString(),
            ),
            StatCard(
              title: strings.backlogValue,
              value: _formatCurrency(insights.backlogValue, currency),
            ),
            StatCard(
              title: strings.unplayedBacklog,
              value: insights.unplayedBacklogGames.length.toString(),
            ),
            StatCard(
              title: strings.unplayedBacklogValue,
              value: _formatCurrency(insights.unplayedBacklogValue, currency),
            ),
            StatCard(
              title: strings.completionRate,
              value: _formatPercent(insights.completionRate),
            ),
            StatCard(
              title: strings.abandonedSpend,
              value: _formatCurrency(insights.abandonedValue, currency),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInsightSection({
    required BuildContext context,
    required AppStrings strings,
    required AppCurrency currency,
    required IconData icon,
    required String title,
    required List<SteamPurchaseInsight> items,
    String? description,
    bool showPriority = false,
  }) {
    final theme = Theme.of(context);
    final visibleItems = items.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.headlineSmall)),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (visibleItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              strings.noInsightItems,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final item in visibleItems)
            _InsightPurchaseCard(
              insight: item,
              strings: strings,
              currency: currency,
              showPriority: showPriority,
              onTap: onPurchaseTap == null
                  ? null
                  : () => onPurchaseTap!(item.purchase),
            ),
      ],
    );
  }

  String _formatCurrency(double value, AppCurrency currency) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}';
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '-';
    }

    return '${(value * 100).round()} %';
  }
}

class _InsightPurchaseCard extends StatelessWidget {
  final SteamPurchaseInsight insight;
  final AppStrings strings;
  final AppCurrency currency;
  final bool showPriority;
  final VoidCallback? onTap;

  const _InsightPurchaseCard({
    required this.insight,
    required this.strings,
    required this.currency,
    required this.showPriority,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final titleBlock = _buildTitleBlock(context);
              final mainMetric = Text(
                showPriority
                    ? '${strings.priority}: ${_priorityLabel()}'
                    : _formatCurrency(insight.totalPrice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    const SizedBox(height: 8),
                    mainMetric,
                    const SizedBox(height: 8),
                    _buildMetricChips(context),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: mainMetric,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMetricChips(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBlock(BuildContext context) {
    final theme = Theme.of(context);
    final status = insight.purchase.gameStatus == null
        ? strings.noGameStatus
        : strings.gameStatusLabel(insight.purchase.gameStatus!);
    final subtitleParts = [status, _formatDate(insight.purchase.purchaseDate)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          insight.purchase.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitleParts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChips(BuildContext context) {
    final chips = [
      _InsightChip(
        icon: Icons.payments,
        label: _formatCurrency(insight.totalPrice),
      ),
      _InsightChip(
        icon: Icons.timer,
        label: _formatPlaytime(insight.playtimeHours),
      ),
      if (insight.pricePerHour != null)
        _InsightChip(
          icon: Icons.speed,
          label: _formatPricePerHour(insight.pricePerHour!),
        ),
      for (final reason in insight.reasons)
        _InsightChip(icon: _reasonIcon(reason), label: _reasonLabel(reason)),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  String _priorityLabel() {
    if (insight.score >= 70) {
      return strings.priorityHigh;
    }

    if (insight.score >= 45) {
      return strings.priorityMedium;
    }

    return strings.priorityLow;
  }

  IconData _reasonIcon(SteamInsightReason reason) {
    return switch (reason) {
      SteamInsightReason.missingStatus => Icons.help_outline,
      SteamInsightReason.noPlaytime => Icons.timer_off,
      SteamInsightReason.barelyStarted => Icons.play_circle_outline,
      SteamInsightReason.open => Icons.inbox,
      SteamInsightReason.active => Icons.play_arrow,
      SteamInsightReason.expensive => Icons.payments,
      SteamInsightReason.old => Icons.history,
      SteamInsightReason.highCostPerHour => Icons.speed,
      SteamInsightReason.wellPlayed => Icons.done_all,
    };
  }

  String _reasonLabel(SteamInsightReason reason) {
    return switch (reason) {
      SteamInsightReason.missingStatus => strings.reasonMissingStatus,
      SteamInsightReason.noPlaytime => strings.reasonNoPlaytime,
      SteamInsightReason.barelyStarted => strings.reasonBarelyStarted,
      SteamInsightReason.open => strings.reasonOpen,
      SteamInsightReason.active => strings.reasonActive,
      SteamInsightReason.expensive => strings.reasonExpensive,
      SteamInsightReason.old => strings.reasonOld,
      SteamInsightReason.highCostPerHour => strings.reasonHighCostPerHour,
      SteamInsightReason.wellPlayed => strings.reasonWellPlayed,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _formatCurrency(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}';
  }

  String _formatPlaytime(double? hours) {
    if (hours == null || hours <= 0) {
      return strings.noPlaytime;
    }

    final hasFraction = hours != hours.roundToDouble();
    final formatted = hours.toStringAsFixed(hasFraction ? 1 : 0);

    return '${formatted.replaceAll('.', ',')} h';
  }

  String _formatPricePerHour(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}/h';
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InsightChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
