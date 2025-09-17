import 'package:flutter/material.dart';

/// Simple reusable card used to highlight financial indicators (TPS, RDR) or
/// mission progress summaries on the dashboard.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trailing,
    this.backgroundColor,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = backgroundColor ?? theme.cardTheme.color;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 16),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
