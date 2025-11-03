import 'package:flutter/material.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../widgets/mission_details_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Missões',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
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
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    'Acompanhe seu progresso nas missões ativas. O sistema atualiza automaticamente conforme você realiza transações.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Missões Ativas',
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
                          '${data.activeMissions.length} ativas',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (data.activeMissions.isEmpty)
                    const _EmptyState(
                      message:
                          'Sem missões ativas no momento.\nContinue realizando transações para receber novas missões!',
                    )
                  else
                    ...data.activeMissions.map(
                      (mission) => GestureDetector(
                        onTap: () async {
                          final updated = await showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) => MissionDetailsSheet(
                              missionProgress: mission,
                              repository: _repository,
                              onUpdate: _refresh,
                            ),
                          );
                          if (updated == true) {
                            _refresh();
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

  /// Retorna cor baseada no tipo de missão
  Color _getMissionTypeColor(String type) {
    switch (type) {
      case 'ONBOARDING':
        return const Color(0xFF9C27B0); // Roxo
      case 'TPS_IMPROVEMENT':
        return const Color(0xFF4CAF50); // Verde
      case 'RDR_REDUCTION':
        return const Color(0xFFF44336); // Vermelho
      case 'ILI_BUILDING':
        return const Color(0xFF2196F3); // Azul
      case 'ADVANCED':
        return const Color(0xFFFF9800); // Laranja
      default:
        return const Color(0xFF607D8B); // Cinza
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

    // Calcular dias restantes
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getMissionTypeColor(mission.mission.missionType),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getMissionTypeDescription(mission.mission.missionType),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${mission.mission.rewardPoints} XP',
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
                  Icon(
                    Icons.celebration_outlined,
                    color: AppColors.support,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Missão concluída! Você ganhou ${mission.mission.rewardPoints} XP',
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
