import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import 'chart_helpers.dart';

class CashflowChart extends StatelessWidget {
  const CashflowChart({
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

    final maxValue = cashflow
        .expand((e) => [e.income, e.expense, e.aportes])
        .reduce((a, b) => a > b ? a : b);
    final interval = ChartHelpers.calculateInterval(maxValue);
    final hasProjections = cashflow.any((p) => p.isProjection);

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
          _buildHeader(theme, hasProjections),
          const SizedBox(height: 16),
          _buildLegend(hasProjections),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _buildChart(theme, interval, hasProjections),
          ),
          const SizedBox(height: 16),
          _buildFooterLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool hasProjections) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolução Temporal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${cashflow.length} meses',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildTouchIndicator(theme),
      ],
    );
  }

  Widget _buildTouchIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 14,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 4),
          Text(
            'Detalhes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(bool hasProjections) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        const DashedLegendItem(
          label: '💰 ${UxStrings.income}',
          color: AppColors.success,
        ),
        const DashedLegendItem(
          label: '💸 ${UxStrings.expense}',
          color: AppColors.alert,
        ),
        const DashedLegendItem(
          label: '🏦 Aportes',
          color: AppColors.primary,
        ),
        if (hasProjections)
          DashedLegendItem(
            label: '🔮 Projeção',
            color: Colors.grey[400]!,
            isDashed: true,
          ),
      ],
    );
  }

  Widget _buildChart(ThemeData theme, double interval, bool hasProjections) {
    return LineChart(
      LineChartData(
        gridData: _buildGridData(interval),
        titlesData: _buildTitlesData(theme, interval),
        borderData: _buildBorderData(),
        lineBarsData: [
          _buildIncomeLine(),
          if (hasProjections) ..._buildProjectionLines(true),
          _buildExpenseLine(),
          if (hasProjections) ..._buildProjectionLines(false),
          _buildAportesLine(),
          if (hasProjections) ..._buildAportesProjectionLines(),
        ],
        lineTouchData: _buildTouchData(theme),
      ),
    );
  }

  FlGridData _buildGridData(double interval) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: interval,
      verticalInterval: 1,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.white.withOpacity(0.05),
          strokeWidth: 1,
          dashArray: value == 0 ? null : [5, 5],
        );
      },
      getDrawingVerticalLine: (value) {
        return FlLine(
          color: Colors.white.withOpacity(0.03),
          strokeWidth: 1,
        );
      },
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
            if (value == 0) {
              return const SizedBox.shrink();
            }
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
          interval: 1,
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

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border(
        left: BorderSide(color: Colors.white.withOpacity(0.1)),
        bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    );
  }

  /// Build spots for a line, only including real data points (not projections)
  /// If there are gaps in future data, don't extend the line
  List<FlSpot> _buildRealDataSpots(double Function(CashflowPoint) getValue) {
    final spots = <FlSpot>[];
    
    // Find the last real data point index
    int lastRealIndex = -1;
    for (var i = cashflow.length - 1; i >= 0; i--) {
      if (!cashflow[i].isProjection && getValue(cashflow[i]) > 0) {
        lastRealIndex = i;
        break;
      }
    }
    
    // Only include real data points up to the last one with data
    for (var i = 0; i < cashflow.length; i++) {
      final point = cashflow[i];
      if (!point.isProjection) {
        // Check if there's any real data after this point
        final hasDataAfter = i <= lastRealIndex || getValue(point) > 0;
        if (hasDataAfter || i <= lastRealIndex) {
          spots.add(FlSpot(i.toDouble(), getValue(point)));
        }
      }
    }
    
    return spots;
  }

  LineChartBarData _buildIncomeLine() {
    final spots = _buildRealDataSpots((p) => p.income);
    
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: AppColors.success,
      barWidth: 3.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: AppColors.success,
            strokeWidth: 2,
            strokeColor: const Color(0xFF1E1E1E),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.success.withOpacity(0.3),
            AppColors.success.withOpacity(0.05),
          ],
        ),
      ),
      shadow: Shadow(
        color: AppColors.success.withOpacity(0.3),
        blurRadius: 8,
      ),
    );
  }

  LineChartBarData _buildExpenseLine() {
    final spots = _buildRealDataSpots((p) => p.expense);
    
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: AppColors.alert,
      barWidth: 3.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: AppColors.alert,
            strokeWidth: 2,
            strokeColor: const Color(0xFF1E1E1E),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.alert.withOpacity(0.3),
            AppColors.alert.withOpacity(0.05),
          ],
        ),
      ),
      shadow: Shadow(
        color: AppColors.alert.withOpacity(0.3),
        blurRadius: 8,
      ),
    );
  }

  List<LineChartBarData> _buildProjectionLines(bool isIncome) {
    final projectionLines = <LineChartBarData>[];

    // Find the first projection index
    int? firstProjectionIndex;
    for (var i = 0; i < cashflow.length; i++) {
      if (cashflow[i].isProjection) {
        firstProjectionIndex = i;
        break;
      }
    }

    if (firstProjectionIndex == null || firstProjectionIndex == 0) {
      return projectionLines;
    }

    // Get the value from the last real data point
    final lastRealValue = isIncome
        ? cashflow[firstProjectionIndex - 1].income
        : cashflow[firstProjectionIndex - 1].expense;

    // Check if there are any values > 0 in projections
    bool hasFutureValues = false;
    for (var i = firstProjectionIndex; i < cashflow.length; i++) {
      if (cashflow[i].isProjection) {
        final val = isIncome ? cashflow[i].income : cashflow[i].expense;
        if (val > 0) {
          hasFutureValues = true;
          break;
        }
      }
    }

    // Don't show projection line if there's no real data AND no future data
    if (lastRealValue <= 0 && !hasFutureValues) {
      return projectionLines;
    }

    final projectionSpots = <FlSpot>[];

    // Start from the last real data point
    projectionSpots.add(FlSpot(
      (firstProjectionIndex - 1).toDouble(),
      lastRealValue,
    ));

    // Add projection points
    for (var i = firstProjectionIndex; i < cashflow.length; i++) {
      if (cashflow[i].isProjection) {
        final value = isIncome ? cashflow[i].income : cashflow[i].expense;
        projectionSpots.add(FlSpot(i.toDouble(), value));
      }
    }

    final baseColor = isIncome ? AppColors.success : AppColors.alert;

    projectionLines.add(
      LineChartBarData(
        spots: projectionSpots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: baseColor.withOpacity(0.5),
        barWidth: 2.5,
        isStrokeCapRound: true,
        dashArray: [8, 4],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            // Don't show dot for the first point (connection point)
            if (index == 0) return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0, strokeColor: Colors.transparent);
            return FlDotCirclePainter(
              radius: 3,
              color: baseColor.withOpacity(0.6),
              strokeWidth: 1.5,
              strokeColor: const Color(0xFF1E1E1E),
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      ),
    );

    return projectionLines;
  }

  LineChartBarData _buildAportesLine() {
    final spots = _buildRealDataSpots((p) => p.aportes);
    
    // Don't render if no real aportes data
    if (spots.isEmpty || spots.every((s) => s.y == 0)) {
      return LineChartBarData(spots: []);
    }
    
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: AppColors.primary,
      barWidth: 3.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: AppColors.primary,
            strokeWidth: 2,
            strokeColor: const Color(0xFF1E1E1E),
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.3),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
      ),
      shadow: Shadow(
        color: AppColors.primary.withOpacity(0.3),
        blurRadius: 8,
      ),
    );
  }

  List<LineChartBarData> _buildAportesProjectionLines() {
    final projectionLines = <LineChartBarData>[];

    // Find the first projection index
    int? firstProjectionIndex;
    for (var i = 0; i < cashflow.length; i++) {
      if (cashflow[i].isProjection) {
        firstProjectionIndex = i;
        break;
      }
    }

    if (firstProjectionIndex == null || firstProjectionIndex == 0) {
      return projectionLines;
    }

    // Get the value from the last real data point
    final lastRealValue = cashflow[firstProjectionIndex - 1].aportes;

    // Check if there are any values > 0 in projections
    bool hasFutureValues = false;
    for (var i = firstProjectionIndex; i < cashflow.length; i++) {
      if (cashflow[i].isProjection && cashflow[i].aportes > 0) {
        hasFutureValues = true;
        break;
      }
    }

    // Don't show projection line if there's no real aportes data AND no future data
    if (lastRealValue <= 0 && !hasFutureValues) {
      return projectionLines;
    }

    final projectionSpots = <FlSpot>[];

    // Start from the last real data point
    projectionSpots.add(FlSpot(
      (firstProjectionIndex - 1).toDouble(),
      lastRealValue,
    ));

    // Add projection points
    for (var i = firstProjectionIndex; i < cashflow.length; i++) {
      if (cashflow[i].isProjection) {
        projectionSpots.add(FlSpot(
          i.toDouble(),
          cashflow[i].aportes,
        ));
      }
    }

    projectionLines.add(
      LineChartBarData(
        spots: projectionSpots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: AppColors.primary.withOpacity(0.5),
        barWidth: 2.5,
        isStrokeCapRound: true,
        dashArray: [8, 4],
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            // Don't show dot for the first point (connection point)
            if (index == 0) return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0, strokeColor: Colors.transparent);
            return FlDotCirclePainter(
              radius: 3,
              color: AppColors.primary.withOpacity(0.6),
              strokeWidth: 1.5,
              strokeColor: const Color(0xFF1E1E1E),
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      ),
    );

    return projectionLines;
  }

  LineTouchData _buildTouchData(ThemeData theme) {
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchSpotThreshold: 30,
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes.map((index) {
          return TouchedSpotIndicatorData(
            FlLine(
              color: Colors.white.withOpacity(0.5),
              strokeWidth: 2,
              dashArray: [5, 5],
            ),
            FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: bar.color ?? Colors.white,
                  strokeWidth: 3,
                  strokeColor: Colors.white,
                );
              },
            ),
          );
        }).toList();
      },
      touchTooltipData: LineTouchTooltipData(
        tooltipRoundedRadius: 12,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tooltipMargin: 8,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipColor: (touchedSpot) => const Color(0xFF2D2D2D),
        getTooltipItems: (touchedSpots) => _buildTooltipItems(touchedSpots),
      ),
    );
  }

  List<LineTooltipItem?> _buildTooltipItems(List<LineBarSpot> touchedSpots) {
    if (touchedSpots.isEmpty) return [];

    final index = touchedSpots.first.x.toInt();
    if (index < 0 || index >= cashflow.length) return [];

    final point = cashflow[index];
    final monthName = ChartHelpers.formatMonthName(point.month);
    final income = point.income;
    final expense = point.expense;
    final aportes = point.aportes;
    // Aportes são transferências para poupança/investimento, não reduzem o saldo
    final balance = income - expense;
    final isProjection = point.isProjection;

    return touchedSpots.asMap().entries.map((entry) {
      final spotIndex = entry.key;
      if (spotIndex == 0) {
        return LineTooltipItem(
          '${isProjection ? '🔮 ' : ''}$monthName${isProjection ? ' (Projeção)' : ''}\n',
          TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontStyle: isProjection ? FontStyle.italic : FontStyle.normal,
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
                  '${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(aportes)}\n',
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
              text: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                  .format(balance),
              style: TextStyle(
                color: balance >= 0 ? AppColors.success : AppColors.alert,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        );
      } else {
        return null;
      }
    }).toList();
  }

  Widget _buildFooterLegend() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LegendItem(color: AppColors.success, label: UxStrings.income),
        SizedBox(width: 24),
        LegendItem(color: AppColors.alert, label: UxStrings.expense),
      ],
    );
  }
}
