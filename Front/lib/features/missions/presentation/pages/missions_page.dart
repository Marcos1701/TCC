import 'package:flutter/material.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../data/missions_viewmodel.dart';
import '../widgets/mission_catalog_highlights.dart';
import '../widgets/mission_details_sheet.dart';
import '../widgets/mission_impact_visualization.dart';

class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  final _repository = FinanceRepository();
  final _cacheManager = CacheManager();
  late final MissionsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MissionsViewModel(repository: _repository);
    _viewModel.loadMissions();
    _cacheManager.addListener(_onCacheInvalidated);

    // Observe mission celebrations
    _viewModel.addListener(_checkForCelebrations);
    AnalyticsService.trackScreenView('missions');
  }

  @override
  void dispose() {
    _viewModel.removeListener(_checkForCelebrations);
    _cacheManager.removeListener(_onCacheInvalidated);
    _viewModel.dispose();
    AnalyticsService.trackScreenExit('missions');
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.missions)) {
      _viewModel.refreshSilently();
      _cacheManager.clearInvalidation(CacheType.missions);
    }
  }

  void _checkForCelebrations() {
    // Check for newly completed missions to celebrate
    if (_viewModel.newlyCompleted.isNotEmpty && mounted) {
      for (final missionId in _viewModel.newlyCompleted) {
        final mission = _viewModel.completedMissions.firstWhere(
          (m) => m.mission.id == missionId,
          orElse: () => _viewModel.activeMissions.firstWhere(
            (m) => m.mission.id == missionId,
          ),
        );

        FeedbackService.showMissionCompleted(
          context,
          missionName: mission.mission.title,
          xpReward: mission.mission.rewardPoints,
          coinsReward: null, // Can be added in the future
        );

        _viewModel.markMissionAsViewed(missionId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          UxStrings.challenges,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _viewModel.loadMissions(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _viewModel.loadMissions(),
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) {
              if (_viewModel.isLoading && _viewModel.activeMissions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_viewModel.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Não foi possível carregar os dados',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _viewModel.errorMessage ??
                          'Não foi possível carregar os desafios.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _viewModel.loadMissions(),
                      icon: const Icon(Icons.refresh),
                      label: const Text(UxStrings.tryAgain),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'Seus desafios ativos e recomendações personalizadas. Complete desafios para ganhar XP.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  MissionImpactVisualization(viewModel: _viewModel),
                  const SizedBox(height: 16),
                  MissionRecommendationsSection(viewModel: _viewModel),
                  const SizedBox(height: 24),
                  if (_viewModel.categorySummaries.isNotEmpty) ...[
                    CategoryMissionBadgeList(viewModel: _viewModel),
                    const SizedBox(height: 24),
                  ],
                  if (_viewModel.goalSummaries.isNotEmpty) ...[
                    GoalMissionPanel(viewModel: _viewModel),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        UxStrings.activeChallenges,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_viewModel.activeMissions.length} ${_viewModel.activeMissions.length == 1 ? 'ativo' : 'ativos'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_viewModel.activeMissions.isEmpty)
                    const _EmptyState(
                      message:
                          'Nenhum desafio ativo no momento.\nRegistre transações para receber novos desafios personalizados!',
                    )
                  else
                    ..._viewModel.activeMissions.map(
                      (mission) => GestureDetector(
                        onTap: () async {
                          final updated = await showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) => MissionDetailsSheet(
                              missionProgress: mission,
                              repository: _repository,
                              onUpdate: () => _viewModel.refreshSilently(),
                            ),
                          );
                          if (updated == true) {
                            _viewModel.refreshSilently();
                          }
                        },
                        child: _ActiveMissionCard(mission: mission),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveMissionCard extends StatelessWidget {
  const _ActiveMissionCard({
    required this.mission,
  });

  final MissionProgressModel mission;

  /// Returns color based on mission type
  Color _getMissionTypeColor(String type) {
    switch (type) {
      case 'ONBOARDING':
        return const Color(0xFF9C27B0); // Purple
      case 'TPS_IMPROVEMENT':
        return const Color(0xFF4CAF50); // Green
      case 'RDR_REDUCTION':
        return const Color(0xFFF44336); // Red
      case 'ILI_BUILDING':
        return const Color(0xFF2196F3); // Blue
      case 'ADVANCED':
        return const Color(0xFFFF9800); // Orange
      default:
        return const Color(0xFF607D8B); // Grey
    }
  }

  String _getMissionTypeDescription(String type) {
    switch (type) {
      case 'ONBOARDING':
        return 'Introdução';
      case 'TPS_IMPROVEMENT':
        return 'Melhoria de TPS';
      case 'RDR_REDUCTION':
        return 'Redução de RDR';
      case 'ILI_BUILDING':
        return 'Construção de ILI';
      case 'ADVANCED':
        return 'Avançado';
      default:
        return 'Geral';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = mission.progress.clamp(0, 100) / 100;
    final tokens = theme.extension<AppDecorations>()!;

    // Calculate remaining days
    String deadlineText = 'Sem prazo';
    Color deadlineColor = Colors.grey[400]!;
    if (mission.startedAt != null && mission.mission.durationDays > 0) {
      final endDate = mission.startedAt!.add(
        Duration(days: mission.mission.durationDays),
      );
      final daysRemaining = endDate.difference(DateTime.now()).inDays;

      if (daysRemaining < 0) {
        deadlineText = 'Expirado';
        deadlineColor = AppColors.alert;
      } else if (daysRemaining == 0) {
        deadlineText = 'Último dia';
        deadlineColor = AppColors.alert;
      } else if (daysRemaining <= 3) {
        deadlineText = '$daysRemaining dias restantes';
        deadlineColor = const Color(0xFFFF9800);
      } else {
        deadlineText = '$daysRemaining dias restantes';
        deadlineColor = Colors.grey[400]!;
      }
    }

    final bool isCompleted = mission.progress >= 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
        border: isCompleted
            ? Border.all(color: AppColors.support.withOpacity(0.3), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge do tipo de missão
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getMissionTypeColor(mission.mission.missionType),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  mission.mission.typeDisplay ??
                      _getMissionTypeDescription(mission.mission.missionType),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              // Badge de origem (template/AI)
              if (mission.mission.source != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: mission.mission.source == 'template'
                        ? const Color(0xFF4CAF50).withOpacity(0.15)
                        : const Color(0xFF2196F3).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: mission.mission.source == 'template'
                          ? const Color(0xFF4CAF50).withOpacity(0.5)
                          : const Color(0xFF2196F3).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mission.mission.source == 'template'
                            ? Icons.bolt
                            : Icons.auto_awesome,
                        size: 10,
                        color: mission.mission.source == 'template'
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mission.mission.source == 'template'
                            ? 'Template'
                            : 'IA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: mission.mission.source == 'template'
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF2196F3),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Indicador de prazo
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: deadlineColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    deadlineText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: deadlineColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mission.mission.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mission.mission.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(
                isCompleted ? AppColors.support : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Informações de progresso e recompensa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.pending_outlined,
                    color: isCompleted ? AppColors.support : Colors.grey[400],
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${mission.progress.toStringAsFixed(0)}% concluído',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCompleted ? AppColors.support : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${mission.mission.rewardPoints} pontos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Mensagem de conclusão
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.support.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.support.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration_outlined,
                    color: AppColors.support,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Desafio concluído! Você ganhou ${mission.mission.rewardPoints} pontos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.support,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
