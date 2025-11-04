import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/mission_progress.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

/// Sheet que exibe detalhes completos de uma missão com breakdown de progresso
class MissionDetailsSheet extends StatefulWidget {
  const MissionDetailsSheet({
    super.key,
    required this.missionProgress,
    required this.repository,
    required this.onUpdate,
  });

  final MissionProgressModel missionProgress;
  final FinanceRepository repository;
  final VoidCallback onUpdate;

  @override
  State<MissionDetailsSheet> createState() => _MissionDetailsSheetState();
}

class _MissionDetailsSheetState extends State<MissionDetailsSheet> {
  Map<String, dynamic>? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final details = await widget.repository
          .fetchMissionProgressDetails(widget.missionProgress.id);

      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar detalhes';
        _loading = false;
      });
    }
  }

  Color _getMissionTypeColor(String type) {
    switch (type) {
      case 'ONBOARDING':
        return const Color(0xFF9C27B0);
      case 'TPS_IMPROVEMENT':
        return const Color(0xFF4CAF50);
      case 'RDR_REDUCTION':
        return const Color(0xFFF44336);
      case 'ILI_BUILDING':
        return const Color(0xFF2196F3);
      case 'ADVANCED':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF607D8B);
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
    final tokens = theme.extension<AppDecorations>()!;
    final typeColor =
        _getMissionTypeColor(widget.missionProgress.mission.missionType);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.flag_outlined,
                      color: typeColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.missionProgress.mission.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getMissionTypeDescription(
                              widget.missionProgress.mission.missionType),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1),

            // Conteúdo
            Flexible(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey[400]),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _loadDetails,
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProgressSection(theme, tokens),
                              const SizedBox(height: 24),
                              _buildDescriptionSection(theme, tokens),
                              const SizedBox(height: 24),
                              _buildInfoSection(theme, tokens),
                              if (_details?['progress_breakdown'] != null) ...[
                                const SizedBox(height: 24),
                                _buildBreakdownSection(theme, tokens),
                              ],
                              if (_details?['progress_timeline'] != null) ...[
                                const SizedBox(height: 24),
                                _buildTimelineSection(theme, tokens),
                              ],
                              if (_details?['current_vs_initial'] != null) ...[
                                const SizedBox(height: 24),
                                _buildComparisonSection(theme, tokens),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme, AppDecorations tokens) {
    final progress = widget.missionProgress.progress.clamp(0, 100) / 100;
    final isCompleted = widget.missionProgress.progress >= 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: isCompleted
              ? AppColors.support.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isCompleted ? AppColors.support : AppColors.primary)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.pending_outlined,
                      color: isCompleted ? AppColors.support : AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.missionProgress.progress.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isCompleted ? AppColors.support : AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(
                isCompleted ? AppColors.support : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(ThemeData theme, AppDecorations tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descrição',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.missionProgress.mission.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[300],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme, AppDecorations tokens) {
    final mission = widget.missionProgress.mission;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(theme, 'Recompensa', '+${mission.rewardPoints} XP',
              Icons.star_rounded, AppColors.primary),
          const SizedBox(height: 12),
          _buildInfoRow(
              theme,
              'Dificuldade',
              mission.difficulty == 'EASY'
                  ? 'Fácil'
                  : mission.difficulty == 'MEDIUM'
                      ? 'Média'
                      : 'Difícil',
              Icons.signal_cellular_alt,
              _getDifficultyColor(mission.difficulty)),
          if (_details?['days_remaining'] != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
                theme,
                'Tempo restante',
                '${_details!['days_remaining']} dias',
                Icons.timer_outlined,
                _getDeadlineColor(_details!['days_remaining'])),
          ],
          if (widget.missionProgress.startedAt != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
                theme,
                'Iniciada em',
                DateFormat('dd/MM/yyyy')
                    .format(widget.missionProgress.startedAt!),
                Icons.play_arrow,
                Colors.grey[400]!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      ThemeData theme, String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownSection(ThemeData theme, AppDecorations tokens) {
    final breakdown = _details!['progress_breakdown'] as Map<String, dynamic>;
    final components =
        breakdown['components'] as List<dynamic>? ?? <dynamic>[];

    if (components.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalhamento do Progresso',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...components.map((comp) {
            final component = comp as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildComponentCard(theme, component),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComponentCard(ThemeData theme, Map<String, dynamic> component) {
    final indicator = component['indicator'] as String;
    final name = component['name'] as String;
    final initial = component['initial'] as num;
    final current = component['current'] as num;
    final target = component['target'] as num;
    final progress = (component['progress'] as num).toDouble() / 100;
    final met = component['met'] as bool;

    // Determinar se deve formatar como inteiro ou decimal
    final isInteger = indicator == 'Transações' || 
                      (initial == initial.toInt() && 
                       current == current.toInt() && 
                       target == target.toInt());

    String formatNumber(num value) {
      if (isInteger) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(1);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border:
            met ? Border.all(color: AppColors.support.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                indicator,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: met ? AppColors.support : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (met)
                Icon(Icons.check_circle, color: AppColors.support, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFF1E1E1E),
            valueColor: AlwaysStoppedAnimation(
              met ? AppColors.support : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inicial',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    formatNumber(initial),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Atual',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    formatNumber(current),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Meta',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    formatNumber(target),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: met ? AppColors.support : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(ThemeData theme, AppDecorations tokens) {
    final timeline = _details!['progress_timeline'] as List<dynamic>? ??
        <dynamic>[];

    if (timeline.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linha do Tempo',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...timeline.map((item) {
            final event = item as Map<String, dynamic>;
            return _buildTimelineItem(theme, event);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ThemeData theme, Map<String, dynamic> event) {
    final label = event['label'] as String;
    final timestamp = event['timestamp'] as String?;
    final isFuture = event['is_future'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isFuture
                  ? Colors.grey[800]
                  : AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getEventIcon(event['event'] as String),
              color: isFuture ? Colors.grey[600] : AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm')
                        .format(DateTime.parse(timestamp)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(ThemeData theme, AppDecorations tokens) {
    final comparison =
        _details!['current_vs_initial'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolução dos Indicadores',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparação entre os valores no início da missão e os valores atuais',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...comparison.entries.map((entry) {
            final indicator = entry.key.toUpperCase();
            final data = entry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  _buildComparisonRow(theme, indicator, data),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
      ThemeData theme, String indicator, Map<String, dynamic> data) {
    final initial = data['initial'] as num;
    final current = data['current'] as num;
    final change = data['change'] as num;
    final isPositive = change > 0;

    // Determinar a mensagem de mudança baseada no indicador
    String getChangeDescription() {
      if (change == 0) return 'Sem alteração';
      
      switch (indicator) {
        case 'TPS':
          return isPositive ? 'Poupando mais' : 'Poupando menos';
        case 'RDR':
          return isPositive ? 'Dívida aumentou' : 'Dívida reduziu';
        case 'ILI':
          return isPositive ? 'Reserva cresceu' : 'Reserva diminuiu';
        default:
          return isPositive ? 'Aumentou' : 'Diminuiu';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                indicator,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.support : AppColors.alert)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? AppColors.support : AppColors.alert,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isPositive ? AppColors.support : AppColors.alert,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No início',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      initial.toStringAsFixed(1),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.arrow_forward,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atualmente',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.toStringAsFixed(1),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            getChangeDescription(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return AppColors.support;
      case 'MEDIUM':
        return const Color(0xFFFF9800);
      case 'HARD':
        return AppColors.alert;
      default:
        return Colors.grey;
    }
  }

  Color _getDeadlineColor(int days) {
    if (days < 0) return AppColors.alert;
    if (days <= 3) return const Color(0xFFFF9800);
    return Colors.grey[400]!;
  }

  IconData _getEventIcon(String event) {
    switch (event) {
      case 'created':
        return Icons.add_circle_outline;
      case 'started':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check_circle;
      case 'deadline':
        return Icons.flag_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
