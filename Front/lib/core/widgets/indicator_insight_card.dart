import 'package:flutter/material.dart';

import '../models/dashboard.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_extension.dart';

class IndicatorInsightCard extends StatelessWidget {
  const IndicatorInsightCard({
    super.key,
    required this.insight,
    required this.icon,
  });

  final IndicatorInsight insight;
  final IconData icon;

  Color get _baseColor {
    switch (insight.severity) {
      case 'good':
        return AppColors.support;
      case 'attention':
        return AppColors.highlight;
      case 'warning':
        return Color.alphaBlend(
          AppColors.alert.withOpacity(0.35),
          AppColors.highlight,
        );
      case 'critical':
        return AppColors.alert;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
  final isLiquidity = insight.indicator == 'ili';
  final valueLabel = isLiquidity
    ? '${insight.value.toStringAsFixed(1)} meses'
    : '${insight.value.toStringAsFixed(1)}%';
  final targetLabel = isLiquidity
    ? '${insight.target.toStringAsFixed(1)} meses'
    : '${insight.target.toStringAsFixed(1)}%';
  final subtitle = '$valueLabel • meta $targetLabel';
    final brightness = ThemeData.estimateBrightnessForColor(_baseColor);
    final titleColor =
        brightness == Brightness.dark ? Colors.white : AppColors.textPrimary;
    final detailColor = brightness == Brightness.dark
        ? Colors.white70
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: _baseColor.withOpacity(0.45), width: 2),
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _baseColor.withOpacity(0.12),
                  borderRadius: tokens.tileRadius,
                ),
                child: Icon(icon, color: _baseColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  insight.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: detailColor),
          ),
          const SizedBox(height: 12),
          Text(
            insight.message,
            style: theme.textTheme.bodyMedium?.copyWith(color: detailColor),
          ),
        ],
      ),
    );
  }
}
