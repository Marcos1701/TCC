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
    
    final income = totals['INCOME'] ?? 0;
    final expense = totals['EXPENSE'] ?? 0;
    final aportes = totals['APORTES'] ?? 0;
    final balance = income - expense - aportes;
    
    final metrics = [
      SummaryMetric(
        key: 'INCOME',
        title: 'Receitas',
        value: income,
        icon: Icons.arrow_upward_rounded,
        color: AppColors.support,
      ),
      SummaryMetric(
        key: 'EXPENSE',
        title: 'Despesas',
        value: expense,
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
            'Resumo do Período',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          // Top row: Income and Expense
          Row(
            children: [
              Expanded(
                child: SummaryMetricCard(
                  metric: metrics[0],
                  currency: currency,
                  dimmed: activeFilter != null && activeFilter != 'INCOME',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryMetricCard(
                  metric: metrics[1],
                  currency: currency,
                  dimmed: activeFilter != null && activeFilter != 'EXPENSE',
                ),
              ),
            ],
          ),
          // Aportes row (only if > 0)
          if (aportes > 0) ...[
            const SizedBox(height: 10),
            AportesCard(
              aportes: aportes,
              currency: currency,
              dimmed: activeFilter != null,
            ),
          ],
          const SizedBox(height: 10),
          // Bottom row: Balance (full width)
          BalanceCard(
            balance: balance,
            currency: currency,
            dimmed: activeFilter != null,
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

/// Full-width balance card showing net income/expense
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.currency,
    required this.dimmed,
  });

  final double balance;
  final NumberFormat currency;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = balance >= 0;
    final color = isPositive ? AppColors.support : AppColors.alert;
    final icon = isPositive 
        ? Icons.trending_up_rounded 
        : Icons.trending_down_rounded;
    final label = isPositive ? 'Saldo Positivo' : 'Saldo Negativo';

    return AnimatedOpacity(
      opacity: dimmed ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(balance.abs()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isPositive ? '+' : '-',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for displaying savings/investment contributions
class AportesCard extends StatelessWidget {
  const AportesCard({
    super.key,
    required this.aportes,
    required this.currency,
    required this.dimmed,
  });

  final double aportes;
  final NumberFormat currency;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = AppColors.primary;

    return AnimatedOpacity(
      opacity: dimmed ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.savings_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APORTES (POUPANÇA/INVEST.)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.withOpacity(0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currency.format(aportes),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.trending_flat_rounded, color: color, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
