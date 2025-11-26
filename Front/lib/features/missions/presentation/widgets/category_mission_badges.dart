import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/services/analytics_service.dart';
import '../../data/missions_viewmodel.dart';
import 'mission_list_sheet.dart';

/// Lista horizontal de badges de categorias com missões.
class CategoryMissionBadgeList extends StatelessWidget {
  const CategoryMissionBadgeList({
    super.key,
    required this.viewModel,
  });

  final MissionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final items = viewModel.categorySummaries;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        final visibleCount = min(items.length, 8);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categorias em evidência',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final summary = items[index];
                  return CategoryBadge(
                    summary: summary,
                    viewModel: viewModel,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: visibleCount,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Badge individual de categoria com contador de missões.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.summary,
    required this.viewModel,
  });

  final CategoryMissionSummary summary;
  final MissionsViewModel viewModel;

  Future<void> _openCategorySheet(BuildContext context) async {
    if (summary.categoryId == null) {
      return;
    }
    AnalyticsService.trackMissionCollectionViewed(
      collectionType: 'category',
      targetId: summary.categoryId!,
      missionCount: summary.count,
    );
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MissionListSheet(
        title: 'Missões para ${summary.name}',
        loader: () => viewModel.loadMissionsForCategory(
          summary.categoryId!,
          forceReload: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _parseColor(summary.colorHex) ?? Colors.white24;

    return GestureDetector(
      onTap:
          summary.categoryId == null ? null : () => _openCategorySheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
          color: color.withOpacity(0.15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              summary.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.count} missão${summary.count > 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parse de cor hexadecimal.
Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  hex = hex.replaceFirst('#', '');
  buffer.write(hex);
  final value = int.tryParse(buffer.toString(), radix: 16);
  if (value == null) return null;
  return Color(value);
}
