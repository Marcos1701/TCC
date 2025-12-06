import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class SummaryMetric {
  const SummaryMetric({
    required this.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String key;
  final String title;
  final double value;
  final IconData icon;
  final Color color;
}

class TransactionsSummaryStrip extends StatelessWidget {
  const TransactionsSummaryStrip({
    super.key,
    required this.currency,
    required this.totals,
    required this.activeFilter,
  });

  final NumberFormat currency;
  final Map<String, double> totals;
  final String? activeFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final metrics = [
      SummaryMetric(
        key: 'INCOME',
        title: 'Receitas',
        value: totals['INCOME'] ?? 0,
        icon: Icons.arrow_upward_rounded,
        color: AppColors.support,
      ),
      SummaryMetric(
        key: 'EXPENSE',
        title: 'Despesas',
        value: totals['EXPENSE'] ?? 0,
        icon: Icons.arrow_downward_rounded,
        color: AppColors.alert,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do Periodo',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                Expanded(
                  child: SummaryMetricCard(
                    metric: metrics[i],
                    currency: currency,
                    dimmed: activeFilter != null && activeFilter != metrics[i].key,
                  ),
                ),
                if (i < metrics.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class SummaryMetricCard extends StatelessWidget {
  const SummaryMetricCard({
    super.key,
    required this.metric,
    required this.currency,
    required this.dimmed,
  });

  final SummaryMetric metric;
  final NumberFormat currency;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: dimmed ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: metric.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: metric.color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(metric.icon, color: metric.color, size: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: metric.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    metric.title.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: metric.color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metric.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                currency.format(metric.value),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: metric.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
