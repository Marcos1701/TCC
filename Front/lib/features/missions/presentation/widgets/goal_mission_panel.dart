import 'package:flutter/material.dart';

import '../../../../core/constants/mission_constants.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/missions_viewmodel.dart';
import 'mission_list_sheet.dart';

/// Painel com missões vinculadas a metas do usuário.
class GoalMissionPanel extends StatelessWidget {
  const GoalMissionPanel({
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
        final items = viewModel.goalSummaries;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Missões das suas metas',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...items.take(3).map(
                  (summary) => GoalMissionCard(
                    summary: summary,
                    viewModel: viewModel,
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Card individual de missão vinculada a meta.
class GoalMissionCard extends StatelessWidget {
  const GoalMissionCard({
    super.key,
    required this.summary,
    required this.viewModel,
  });

  final GoalMissionSummary summary;
  final MissionsViewModel viewModel;

  Future<void> _openGoalSheet(BuildContext context) async {
    if (summary.goalId == null) {
      return;
    }
    AnalyticsService.trackMissionCollectionViewed(
      collectionType: 'goal',
      targetId: summary.goalId!,
      missionCount: summary.count,
    );
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MissionListSheet(
        title: summary.label,
        loader: () => viewModel.loadMissionsForGoal(
          summary.goalId!,
          forceReload: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: summary.goalId == null ? null : () => _openGoalSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF12121C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${summary.count} missão${summary.count > 1 ? 's' : ''}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: summary.missionTypes
                  .map(
                    (type) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        MissionTypeLabels.getShort(type),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (summary.averageTarget != null) ...[
              const SizedBox(height: 10),
              Text(
                'Alvo médio: ${(summary.averageTarget! * 100).toStringAsFixed(0)}% do objetivo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
