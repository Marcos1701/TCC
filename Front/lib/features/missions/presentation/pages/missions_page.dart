import 'package:flutter/material.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../shared/widgets/section_header.dart';

class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});

  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  final _repository = FinanceRepository();
  late Future<DashboardData> _future = _repository.fetchDashboard();

  Future<void> _refresh() async {
    final data = await _repository.fetchDashboard();
    if (!mounted) return;
    setState(() => _future = Future.value(data));
  }

  Future<void> _startMission(int missionId) async {
    final session = SessionScope.of(context);
    await _repository.startMission(missionId);
    if (!mounted) return;
    await _refresh();
    await session.refreshSession();
    if (!mounted) return;
    _showFeedback('Missão iniciada! Boa jornada.');
  }

  Future<void> _completeMission(MissionProgressModel mission) async {
    final session = SessionScope.of(context);
    await _repository.updateMission(
        progressId: mission.id, status: 'COMPLETED', progress: 100);
    if (!mounted) return;
    await _refresh();
    await session.refreshSession();
    if (!mounted) return;
    _showFeedback('Missão concluída! XP garantido.');
  }

  Future<void> _editProgress(MissionProgressModel mission) async {
    final controller =
        TextEditingController(text: mission.progress.toStringAsFixed(0));
    final updated = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Atualizar progresso'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Percentual (0 a 100)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final value =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              if (value == null) return;
              Navigator.pop(context, value.clamp(0, 100));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (updated == null) return;
    await _repository.updateMission(progressId: mission.id, progress: updated);
    if (!mounted) return;
    await _refresh();
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Sem conexão com as missões agora.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: _refresh, child: const Text('Tentar novamente')),
              ],
            );
          }

          final data = snapshot.data!;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Missões e desafios',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Acompanhe missões ativas e sugestões alinhadas aos seus objetivos.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Em andamento',
                      actionLabel: 'atualizar',
                      onActionTap: _refresh,
                    ),
                    const SizedBox(height: 12),
                    if (data.activeMissions.isEmpty)
                      const _EmptyState(
                          message:
                              'Sem missões ativas. Escolha uma sugestão abaixo.')
                    else
                      ...data.activeMissions.map(
                        (mission) => _ActiveMissionCard(
                          mission: mission,
                          onComplete: () => _completeMission(mission),
                          onEdit: () => _editProgress(mission),
                        ),
                      ),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: 'Sugestões inteligentes',
                      actionLabel: 'ver todas',
                      onActionTap: _refresh,
                    ),
                    const SizedBox(height: 12),
                    if (data.recommendedMissions.isEmpty)
                      const _EmptyState(
                          message: 'Tudo certo! Sem novas sugestões agora.')
                    else
                      ...data.recommendedMissions.map(
                        (mission) => _SuggestedMissionCard(
                          mission: mission,
                          onStart: () => _startMission(mission.id),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActiveMissionCard extends StatelessWidget {
  const _ActiveMissionCard({
    required this.mission,
    required this.onComplete,
    required this.onEdit,
  });

  final MissionProgressModel mission;
  final VoidCallback onComplete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = mission.progress.clamp(0, 100) / 100;
    final tokens = theme.extension<AppDecorations>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: theme.dividerColor),
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mission.mission.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mission.mission.description,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.secondaryContainer,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${mission.progress.toStringAsFixed(0)}% • ${mission.mission.rewardPoints} XP',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  TextButton(onPressed: onEdit, child: const Text('Progresso')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: onComplete, child: const Text('Concluir')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestedMissionCard extends StatelessWidget {
  const _SuggestedMissionCard({
    required this.mission,
    required this.onStart,
  });

  final MissionModel mission;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: theme.dividerColor),
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mission.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mission.description,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;

              final label = Text(
                '${mission.rewardPoints} XP • ${mission.durationDays} dias',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              );

              final action = ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 0,
                  maxWidth: availableWidth.isFinite && availableWidth > 0
                      ? availableWidth * 0.6
                      : 220,
                ),
                child: FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Aceitar'),
                ),
              );

              if (availableWidth.isFinite && availableWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  action,
                ],
              );
            },
          ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: tokens.tileRadius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
