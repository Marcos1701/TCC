import 'package:flutter/material.dart';

import '../models/dashboard.dart';
import '../theme/app_colors.dart';

/// Cartão rápido que mostra os insights de TPS/RDR e missões sugeridos no doc.
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
        return AppColors.success;
      case 'attention':
        return AppColors.warning;
      case 'warning':
        return AppColors.secondary;
      case 'critical':
        return AppColors.danger;
      default:
        return AppColors.surfaceAlt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        '${insight.value.toStringAsFixed(1)}% • meta ${insight.target}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _baseColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                  color: _baseColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _baseColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  insight.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            insight.message,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
