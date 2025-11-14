import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/models/mission.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/missions_viewmodel.dart';
import 'mission_progress_detail_widget.dart';

class MissionRecommendationsSection extends StatefulWidget {
  const MissionRecommendationsSection({
    super.key,
    required this.viewModel,
  });

  final MissionsViewModel viewModel;

  @override
  State<MissionRecommendationsSection> createState() =>
      _MissionRecommendationsSectionState();
}

class _MissionRecommendationsSectionState
    extends State<MissionRecommendationsSection> {
  late final PageController _controller;
  int _currentPage = 0;
  bool _requestedLoad = false;
  bool _trackedInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDataLoaded());
  }

  @override
  void didUpdateWidget(covariant MissionRecommendationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _requestedLoad = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDataLoaded());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ensureDataLoaded() {
    if (_requestedLoad || widget.viewModel.recommendedMissions.isNotEmpty) {
      return;
    }
    _requestedLoad = true;
    widget.viewModel.loadRecommendedMissions(limit: 8);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missões prioritárias',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Escolha o próximo ajuste e execute o passo indicado.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                return IconButton(
                  onPressed: widget.viewModel.isCatalogLoading
                      ? null
                      : () =>
                          widget.viewModel.loadRecommendedMissions(limit: 8),
                  icon: widget.viewModel.isCatalogLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Colors.white),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            if (widget.viewModel.isCatalogLoading &&
                widget.viewModel.recommendedMissions.isEmpty) {
              return const _RecommendationSkeleton(cardHeight: 300, count: 2);
            }

            if (widget.viewModel.catalogError != null &&
                widget.viewModel.recommendedMissions.isEmpty) {
              return _RecommendationError(
                message: widget.viewModel.catalogError!,
                onRetry: () =>
                    widget.viewModel.loadRecommendedMissions(limit: 8),
              );
            }

            if (widget.viewModel.recommendedMissions.isEmpty) {
              return const _RecommendationPlaceholder();
            }

            final missions = widget.viewModel.recommendedMissions;
            _trackInitialLoad(missions);

            return Column(
              children: [
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (index) =>
                        _handlePageChanged(index, missions[index]),
                    itemCount: missions.length,
                    itemBuilder: (context, index) {
                      final mission = missions[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _MissionRecommendationCard(
                          mission: mission,
                          onDetails: () => _showDetails(mission),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _PageIndicator(
                  length: missions.length,
                  currentIndex: _currentPage,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _trackInitialLoad(List<MissionModel> missions) {
    if (_trackedInitialLoad || missions.isEmpty) {
      return;
    }
    _trackedInitialLoad = true;
    AnalyticsService.trackMissionRecommendationsLoaded(
      count: missions.length,
    );
  }

  void _handlePageChanged(int index, MissionModel mission) {
    setState(() => _currentPage = index);
    AnalyticsService.trackMissionRecommendationSwiped(
      missionId: mission.id.toString(),
      missionType: mission.missionType,
      position: index,
    );
  }

  Future<void> _showDetails(MissionModel mission) async {
    if (!mounted) return;
    AnalyticsService.trackMissionRecommendationDetail(
      missionId: mission.id.toString(),
      missionType: mission.missionType,
      position: _currentPage,
      source: mission.source ?? 'unknown',
    );
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RecommendationPreviewSheet(
        mission: mission,
      ),
    );
  }
}

class _MissionRecommendationCard extends StatelessWidget {
  const _MissionRecommendationCard({
    required this.mission,
    required this.onDetails,
  });

  final MissionModel mission;
  final VoidCallback onDetails;

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return const Color(0xFF4CAF50);
      case 'HARD':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }

  _BadgeStyle? _badgeForSource(String? source) {
    switch ((source ?? '').toLowerCase()) {
      case 'template':
        return const _BadgeStyle(
          label: 'Biblioteca',
          icon: Icons.layers_outlined,
          color: Color(0xFF4CAF50),
        );
      case 'ai':
      case 'system':
      case 'context':
        return const _BadgeStyle(
          label: 'Personalizada',
          icon: Icons.tune,
          color: Color(0xFF2196F3),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = mission.targetInfo?['targets'];
    final _BadgeStyle? sourceBadge = _badgeForSource(mission.source);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F33), Color(0xFF111118)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            _difficultyColor(mission.difficulty).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: _difficultyColor(mission.difficulty),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            mission.difficultyDisplay ?? mission.difficulty,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: _difficultyColor(mission.difficulty),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        mission.missionTypeLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (sourceBadge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: sourceBadge.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: sourceBadge.color.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sourceBadge.icon,
                              size: 10,
                              color: sourceBadge.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sourceBadge.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: sourceBadge.color,
                                fontWeight: FontWeight.w600,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics_outlined,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      'Indicadores',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mission.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          MissionProgressDetailWidget(
            mission: mission,
            compact: true,
          ),
          if (targets is List && targets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: targets
                  .whereType<Map>()
                  .map((target) => _TargetChip(target))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conclua e registre para liberar a recompensa.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDetails,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Ver detalhes'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _MissionListSheet extends StatefulWidget {
  const _MissionListSheet({
    required this.title,
    required this.loader,
  });

  final String title;
  final Future<List<MissionModel>> Function() loader;

  @override
  State<_MissionListSheet> createState() => _MissionListSheetState();
}

class _MissionListSheetState extends State<_MissionListSheet> {
  late Future<List<MissionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _retry() {
    setState(() {
      _future = widget.loader();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF06060C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Toque para abrir os detalhes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<MissionModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return _MissionListError(onRetry: _retry);
                    }
                    final missions = snapshot.data ?? const [];
                    if (missions.isEmpty) {
                      return const _MissionListEmpty();
                    }
                    return ListView.separated(
                      controller: controller,
                      itemCount: missions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final mission = missions[index];
                        return _MissionListTile(mission: mission);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MissionListError extends StatelessWidget {
  const _MissionListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 32),
          const SizedBox(height: 12),
          Text(
            'Não foi possível carregar as missões.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _MissionListEmpty extends StatelessWidget {
  const _MissionListEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white38, size: 32),
          const SizedBox(height: 12),
          Text(
            'Nenhuma missão disponível para este filtro.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionListTile extends StatelessWidget {
  const _MissionListTile({required this.mission});

  final MissionModel mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
              Expanded(
                child: Text(
                  mission.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${mission.rewardPoints} pts',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mission.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          MissionProgressDetailWidget(mission: mission, compact: true),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip(this.target);

  final Map target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metric = (target['metric'] as String?) ?? 'TARGET';
    final label = (target['label'] as String?) ?? 'Objetivo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            metric == 'CATEGORY'
                ? Icons.category_outlined
                : Icons.flag_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.length, required this.currentIndex});

  final int length;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}

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
                  return _CategoryBadge(
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

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({
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
      builder: (context) => _MissionListSheet(
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
                  (summary) => _GoalMissionCard(
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

class _GoalMissionCard extends StatelessWidget {
  const _GoalMissionCard({
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
      builder: (context) => _MissionListSheet(
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
                        MissionTypeLabels.labelFor(type),
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

class MissionTypeLabels {
  static String labelFor(String type) {
    switch (type) {
      case 'GOAL_CONSISTENCY':
        return 'Consistência nas metas';
      case 'GOAL_ACHIEVEMENT':
        return 'Acelerar meta';
      case 'GOAL_ACCELERATION':
        return 'Impulsionar meta';
      case 'CATEGORY_REDUCTION':
        return 'Reduzir categoria';
      case 'CATEGORY_SPENDING_LIMIT':
        return 'Manter limite';
      default:
        return 'Missão financeira';
    }
  }
}

class _RecommendationSkeleton extends StatelessWidget {
  const _RecommendationSkeleton({
    required this.cardHeight,
    required this.count,
  });

  final double cardHeight;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: Row(
        children: List.generate(count, (index) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RecommendationPlaceholder extends StatelessWidget {
  const _RecommendationPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        color: const Color(0xFF15151F),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Novas missões surgem quando indicadores pedem atenção. Continue registrando movimentações para destravar desafios.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationError extends StatelessWidget {
  const _RecommendationError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        color: const Color(0xFF211313),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Não foi possível carregar recomendações',
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
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

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

class _RecommendationPreviewSheet extends StatelessWidget {
  const _RecommendationPreviewSheet({
    required this.mission,
  });

  final MissionModel mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF090910),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                mission.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                mission.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.stars,
                    label: '${mission.rewardPoints} pontos de experiência',
                  ),
                  _InfoChip(
                    icon: Icons.access_time,
                    label: '${mission.durationDays} dias de duração',
                  ),
                  _InfoChip(
                    icon: Icons.security_outlined,
                    label: mission.difficultyDisplay ?? mission.difficulty,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              MissionProgressDetailWidget(mission: mission),
              const SizedBox(height: 20),
              if (mission.tips != null && mission.tips!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dicas inteligentes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...mission.tips!.take(3).map(
                          (tip) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              tip['text'] as String? ??
                                  'Aproveite esta missão.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Fechar'),
              ),
              const SizedBox(height: 8),
              Text(
                'O progresso é recalculado assim que novas transações ou pagamentos são registrados.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
