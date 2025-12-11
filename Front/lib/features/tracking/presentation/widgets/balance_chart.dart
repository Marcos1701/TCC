import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import 'chart_helpers.dart';

class BalanceChart extends StatelessWidget {
  const BalanceChart({
    super.key,
    required this.cashflow,
  });

  final List<CashflowPoint> cashflow;

  @override
  Widget build(BuildContext context) {
    if (cashflow.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    // Aportes são transferências para poupança/investimento, não consomem saldo
    final balances = cashflow.map((e) => e.income - e.expense).toList();
    final maxBalance =
        balances.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
    final maxY = maxBalance < 100 ? 100.0 : maxBalance;
    final interval = ChartHelpers.calculateInterval(maxY);

    final positiveCount = balances.where((b) => b > 0).length;
    final negativeCount = balances.where((b) => b < 0).length;
    final avgBalance = balances.isEmpty
        ? 0.0
        : balances.reduce((a, b) => a + b) / balances.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, avgBalance, positiveCount, negativeCount),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: _buildChart(theme, balances, maxY, interval),
          ),
          const SizedBox(height: 16),
          _buildFooterLegend(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    double avgBalance,
    int positiveCount,
    int negativeCount,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.highlight.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.highlight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      UxStrings.balance,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Média: ${NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0).format(avgBalance)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            avgBalance >= 0 ? AppColors.success : AppColors.alert,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            _BalanceIndicator(
              icon: Icons.trending_up_rounded,
              count: positiveCount,
              color: AppColors.success,
            ),
            const SizedBox(width: 8),
            _BalanceIndicator(
              icon: Icons.trending_down_rounded,
              count: negativeCount,
              color: AppColors.alert,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChart(
    ThemeData theme,
    List<double> balances,
    double maxY,
    double interval,
  ) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxY,
        minY: -maxY,
        barTouchData: _buildTouchData(balances),
        titlesData: _buildTitlesData(theme, interval),
        gridData: _buildGridData(interval),
        borderData: _buildBorderData(),
        barGroups: _buildBarGroups(balances, maxY),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
    );
  }

  BarTouchData _buildTouchData(List<double> balances) {
    return BarTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchTooltipData: BarTouchTooltipData(
        tooltipRoundedRadius: 12,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tooltipMargin: 8,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipColor: (group) => const Color(0xFF2D2D2D),
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return _buildTooltipItem(group, balances);
        },
      ),
    );
  }

  BarTooltipItem? _buildTooltipItem(
    BarChartGroupData group,
    List<double> balances,
  ) {
    final index = group.x.toInt();
    if (index < 0 || index >= cashflow.length) return null;

    final monthStr = cashflow[index].month;
    final monthName = ChartHelpers.formatMonthName(monthStr);
    final balance = balances[index];
    final income = cashflow[index].income;
    final expense = cashflow[index].expense;
    final percentChange = income > 0 ? ((balance / income) * 100) : 0.0;

    return BarTooltipItem(
      '$monthName\n',
      const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      children: [
        const TextSpan(
          text: '💰 ${UxStrings.income}: ',
          style: TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        TextSpan(
          text:
              '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(income)}\n',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: 11,
          ),
        ),
        const TextSpan(
          text: '💸 ${UxStrings.expense}: ',
          style: TextStyle(
            color: AppColors.alert,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        TextSpan(
          text:
              '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(expense)}\n',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: 11,
          ),
        ),
        const TextSpan(
          text: '🏦 Aportes: ',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        TextSpan(
          text:
              '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cashflow[index].aportes)}\n',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: 11,
          ),
        ),
        TextSpan(
          text: '📊 ${UxStrings.balance}: ',
          style: TextStyle(
            color: balance >= 0 ? AppColors.success : AppColors.alert,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        TextSpan(
          text:
              '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(balance)}\n',
          style: TextStyle(
            color: balance >= 0 ? AppColors.success : AppColors.alert,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const TextSpan(
          text: '📈 Margem: ',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        TextSpan(
          text: '${percentChange.toStringAsFixed(1)}%',
          style: TextStyle(
            color: percentChange >= 0 ? AppColors.success : AppColors.alert,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  FlTitlesData _buildTitlesData(ThemeData theme, double interval) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 65,
          interval: interval,
          getTitlesWidget: (value, meta) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                NumberFormat.compactCurrency(
                  locale: 'pt_BR',
                  symbol: 'R\$',
                  decimalDigits: 0,
                ).format(value),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 9,
                ),
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          getTitlesWidget: (value, meta) {
            if (value.toInt() < 0 || value.toInt() >= cashflow.length) {
              return const SizedBox.shrink();
            }
            final monthStr = cashflow[value.toInt()].month;
            final monthLabel = ChartHelpers.formatMonthLabel(monthStr);

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                monthLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  FlGridData _buildGridData(double interval) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (value) {
        if (value == 0) {
          return FlLine(
            color: Colors.white.withOpacity(0.3),
            strokeWidth: 2,
          );
        }
        return FlLine(
          color: Colors.white.withOpacity(0.05),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border(
        left: BorderSide(color: Colors.white.withOpacity(0.1)),
        bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<double> balances, double maxY) {
    return balances.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            width: 14,
            borderRadius: BorderRadius.vertical(
              top: entry.value >= 0 ? const Radius.circular(6) : Radius.zero,
              bottom: entry.value < 0 ? const Radius.circular(6) : Radius.zero,
            ),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: entry.value >= 0
                  ? [
                      AppColors.success.withOpacity(0.7),
                      AppColors.success,
                    ]
                  : [
                      AppColors.alert,
                      AppColors.alert.withOpacity(0.7),
                    ],
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              fromY: -maxY,
              color: Colors.white.withOpacity(0.02),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildFooterLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: AppColors.success,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Positivo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.trending_down_rounded,
                color: AppColors.alert,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Negativo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.alert,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceIndicator extends StatelessWidget {
  const _BalanceIndicator({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
