import 'package:flutter/material.dart';

import '../models/dashboard.dart';
import '../theme/app_colors.dart';

/// Cartão reutilizável para exibir o insight de um indicador financeiro.
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
          AppColors.alert.withValues(alpha: 0.35),
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
    final subtitle = '${insight.value.toStringAsFixed(1)}% • meta ${insight.target}%';
    final brightness = ThemeData.estimateBrightnessForColor(_baseColor);
    final titleColor = brightness == Brightness.dark ? Colors.white : AppColors.textPrimary;
    final detailColor = brightness == Brightness.dark ? Colors.white70 : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _baseColor.withValues(alpha: 0.45), width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
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
                  color: _baseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
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
