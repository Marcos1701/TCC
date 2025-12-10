import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import 'chart_helpers.dart';

class CategoryPieChart extends StatefulWidget {
  const CategoryPieChart({
    super.key,
    required this.title,
    required this.slices,
    required this.baseColor,
  });

  final String title;
  final List<CategorySlice> slices;
  final Color baseColor;

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final total =
        widget.slices.fold<double>(0, (sum, slice) => sum + slice.total);
    final isExpense = widget.baseColor == AppColors.alert;

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
          _buildHeader(theme, total, isExpense),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPieChart(total),
              const SizedBox(width: 24),
              Expanded(
                child: _buildLegend(theme, total),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForColor() {
    if (widget.baseColor == AppColors.alert) {
      return Icons.payments_rounded;
    } else if (widget.baseColor == AppColors.primary) {
      return Icons.savings_rounded;
    } else {
      return Icons.account_balance_wallet_rounded;
    }
  }

  Widget _buildHeader(ThemeData theme, double total, bool isExpense) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.baseColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForColor(),
                  color: widget.baseColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Total: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(total)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widget.baseColor,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            '${widget.slices.length} categorias',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(double total) {
    final isExpense = widget.baseColor == AppColors.alert;

    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              sections: widget.slices.asMap().entries.map((entry) {
                final isTouched = entry.key == _touchedIndex;
                final percentage = (entry.value.total / total) * 100;
                final radius = isTouched ? 52.0 : 45.0;
                final fontSize = isTouched ? 12.0 : 10.0;

                return PieChartSectionData(
                  value: entry.value.total,
                  title: percentage >= 5
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '',
                  color: ChartHelpers.getCategoryColor(
                    entry.key,
                    widget.slices.length,
                    widget.baseColor,
                  ),
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  badgeWidget: isTouched
                      ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D2D),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.touch_app_rounded,
                            size: 16,
                            color: widget.baseColor,
                          ),
                        )
                      : null,
                  badgePositionPercentageOffset: 1.3,
                );
              }).toList(),
            ),
            swapAnimationDuration: const Duration(milliseconds: 300),
            swapAnimationCurve: Curves.easeInOutCubic,
          ),
          _buildCenterIcon(isExpense),
        ],
      ),
    );
  }

  Widget _buildCenterIcon(bool isExpense) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.baseColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        isExpense ? Icons.trending_down : Icons.trending_up,
        color: widget.baseColor,
        size: 28,
      ),
    );
  }

  Widget _buildLegend(ThemeData theme, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.slices.take(6).map((slice) {
          final percentage = (slice.total / total) * 100;
          final index = widget.slices.indexOf(slice);
          final isTouched = index == _touchedIndex;

          return _CategoryLegendItem(
            slice: slice,
            percentage: percentage,
            index: index,
            totalSlices: widget.slices.length,
            baseColor: widget.baseColor,
            isTouched: isTouched,
          );
        }),
        if (widget.slices.length > 6) ...[
          const SizedBox(height: 4),
          _buildMoreCategoriesIndicator(theme),
        ],
      ],
    );
  }

  Widget _buildMoreCategoriesIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.more_horiz_rounded,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            '+${widget.slices.length - 6} categorias',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLegendItem extends StatelessWidget {
  const _CategoryLegendItem({
    required this.slice,
    required this.percentage,
    required this.index,
    required this.totalSlices,
    required this.baseColor,
    required this.isTouched,
  });

  final CategorySlice slice;
  final double percentage;
  final int index;
  final int totalSlices;
  final Color baseColor;
  final bool isTouched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = ChartHelpers.getCategoryColor(
      index,
      totalSlices,
      baseColor,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isTouched ? baseColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTouched ? baseColor.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          _buildColorIndicator(categoryColor),
          const SizedBox(width: 10),
          Expanded(
            child: _buildNameAndValue(theme),
          ),
          const SizedBox(width: 8),
          _buildPercentageBadge(theme),
        ],
      ),
    );
  }

  Widget _buildColorIndicator(Color categoryColor) {
    return Container(
      width: isTouched ? 14 : 12,
      height: isTouched ? 14 : 12,
      decoration: BoxDecoration(
        color: categoryColor,
        shape: BoxShape.circle,
        boxShadow: isTouched
            ? [
                BoxShadow(
                  color: categoryColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildNameAndValue(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slice.name,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isTouched ? Colors.white : Colors.white70,
            fontSize: isTouched ? 12 : 11,
            fontWeight: isTouched ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (isTouched) ...[
          const SizedBox(height: 2),
          Text(
            NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                .format(slice.total),
            style: theme.textTheme.bodySmall?.copyWith(
              color: baseColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPercentageBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTouched
            ? baseColor.withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${percentage.toStringAsFixed(1)}%',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isTouched ? baseColor : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: isTouched ? 11 : 10,
        ),
      ),
    );
  }
}
