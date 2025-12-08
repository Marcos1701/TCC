import 'package:flutter/material.dart';

import '../../../../core/constants/mission_constants.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/services/analytics_service.dart';
import '../../data/missions_viewmodel.dart';
import 'mission_progress_detail_widget.dart';
import 'mission_recommendation_components.dart';

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'Missões Recomendadas',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Escolha uma missão e siga as orientações para progredir.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
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
              return const RecommendationSkeleton(cardHeight: 300, count: 2);
            }

            if (widget.viewModel.catalogError != null &&
                widget.viewModel.recommendedMissions.isEmpty) {
              return RecommendationError(
                message: widget.viewModel.catalogError!,
                onRetry: () =>
                    widget.viewModel.loadRecommendedMissions(limit: 8),
              );
            }

            if (widget.viewModel.recommendedMissions.isEmpty) {
              return const RecommendationPlaceholder();
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
                        child: MissionRecommendationCard(
                          mission: mission,
                          onDetails: () => _showDetails(mission),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                PageIndicator(
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
      builder: (context) => RecommendationPreviewSheet(
        mission: mission,
      ),
    );
  }
}

class MissionRecommendationCard extends StatelessWidget {
  const MissionRecommendationCard({
    super.key,
    required this.mission,
    required this.onDetails,
  });

  final MissionModel mission;
  final VoidCallback onDetails;

  Color _difficultyColor(String difficulty) => DifficultyColors.get(difficulty);


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = mission.targetInfo?['targets'];

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
                  _buildHeader(theme),
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
                          .map((target) => TargetChip(target))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildFooterInfo(theme),
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

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _difficultyColor(mission.difficulty).withOpacity(0.15),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  Widget _buildFooterInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Complete a missão para ganhar pontos de experiência.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
