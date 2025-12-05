import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/mission_constants.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/constants/user_friendly_strings.dart';

/// Sheet que exibe detalhes completos de um desafio com breakdown de progresso
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

  Color _getMissionTypeColor(String type) => MissionTypeColors.get(type);

  String _getMissionTypeDescription(String type) =>
      MissionTypeLabels.getShort(type);

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
                      color: typeColor.withOpacity(0.2),
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
                          widget.missionProgress.mission.typeDisplay ??
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
    final progressMessage = widget.missionProgress.progressMessage;
    final canComplete = widget.missionProgress.canComplete;
    final isOnTrack = widget.missionProgress.isOnTrack;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: isCompleted
              ? AppColors.support.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      .withOpacity(0.2),
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
          
          // Mensagem de progresso da API
          if (progressMessage != null && progressMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (canComplete 
                    ? const Color(0xFF4CAF50) 
                    : isOnTrack 
                        ? const Color(0xFF2196F3) 
                        : const Color(0xFFFF9800)
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (canComplete 
                      ? const Color(0xFF4CAF50) 
                      : isOnTrack 
                          ? const Color(0xFF2196F3) 
                          : const Color(0xFFFF9800)
                  ).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    canComplete 
                        ? Icons.check_circle_outline
                        : isOnTrack
                            ? Icons.trending_up
                            : Icons.info_outline,
                    color: canComplete 
                        ? const Color(0xFF4CAF50) 
                        : isOnTrack 
                            ? const Color(0xFF2196F3) 
                            : const Color(0xFFFF9800),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progressMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[300],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Métricas detalhadas por tipo de missão
          if (widget.missionProgress.metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDetailedMetrics(theme, tokens),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedMetrics(ThemeData theme, AppDecorations tokens) {
    final metrics = widget.missionProgress.metrics;
    final missionType = widget.missionProgress.mission.missionType;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Colors.grey[400],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Métricas Específicas',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Métricas específicas por tipo de missão
          if (missionType == 'TPS_IMPROVEMENT') ..._buildTPSMetrics(theme, metrics)
          else if (missionType == 'RDR_REDUCTION') ..._buildRDRMetrics(theme, metrics)
          else if (missionType == 'ILI_BUILDING') ..._buildILIMetrics(theme, metrics)
          else if (missionType == 'ONBOARDING') ..._buildOnboardingMetrics(theme, metrics)
          else if (missionType == 'ADVANCED') ..._buildAdvancedMetrics(theme, metrics)
          else ..._buildGenericMetrics(theme, metrics),
        ],
      ),
    );
  }
  
  List<Widget> _buildTPSMetrics(ThemeData theme, List<Map<String, dynamic>> metrics) {
    return _buildFormattedMetrics(theme, metrics);
  }
  
  List<Widget> _buildRDRMetrics(ThemeData theme, List<Map<String, dynamic>> metrics) {
    return _buildFormattedMetrics(theme, metrics);
  }
  
  List<Widget> _buildILIMetrics(ThemeData theme, List<Map<String, dynamic>> metrics) {
    return _buildFormattedMetrics(theme, metrics);
  }
  
  List<Widget> _buildOnboardingMetrics(ThemeData theme, List<Map<String, dynamic>> metrics) {
    return _buildFormattedMetrics(theme, metrics);
  }
  
  List<Widget> _buildAdvancedMetrics(ThemeData theme, List<Map<String, dynamic>> metrics) {
    return _buildFormattedMetrics(theme, metrics);
  }
  
  List<Widget> _buildGenericMetrics(ThemeData theme, List<Map<String, dynamic>> metrics) {
    return _buildFormattedMetrics(theme, metrics);
  }
  
  List<Widget> _buildFormattedMetrics(ThemeData theme, List<Map<String, dynamic>> metrics) {
    final List<Widget> widgets = [];
    
    for (int i = 0; i < metrics.length; i++) {
      final metric = metrics[i];
      if (i > 0) {
        widgets.add(const SizedBox(height: 8));
      }
      widgets.add(_buildMetricRow(
        theme,
        metric['label'] as String? ?? '',
        metric['display'] as String? ?? '',
        _getIconFromEmoji(metric['icon'] as String?),
        _getColorFromMetricType(metric['type'] as String?),
      ));
    }
    
    return widgets;
  }
  
  IconData _getIconFromEmoji(String? emoji) {
    switch (emoji) {
      case '📝': return Icons.receipt_long;
      case '💰': return Icons.attach_money;
      case '📊': return Icons.bar_chart;
      case '📉': return Icons.trending_down;
      case '🛡️': return Icons.shield;
      case '📁': return Icons.folder;
      case '🎯': return Icons.flag;
      case '💸': return Icons.money_off;
      case '📈': return Icons.trending_up;
      case '📅': return Icons.calendar_today;
      case '📆': return Icons.event;
      case '💳': return Icons.credit_card;
      default: return Icons.info_outline;
    }
  }
  
  Color _getColorFromMetricType(String? type) {
    switch (type) {
      case 'currency': return const Color(0xFF4CAF50);
      case 'percentage': return const Color(0xFF2196F3);
      case 'count': return const Color(0xFF9C27B0);
      case 'months': return const Color(0xFFFF9800);
      case 'target': return const Color(0xFF2196F3);
      default: return Colors.grey[400]!;
    }
  }
  
  Widget _buildMetricRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
          _buildInfoRow(theme, 'Recompensa', '+${mission.rewardPoints} ${UxStrings.points}',
              Icons.star_rounded, AppColors.primary),
          const SizedBox(height: 12),
          _buildInfoRow(
              theme,
              'Dificuldade',
              mission.difficultyDisplay ?? 
                  (mission.difficulty == 'EASY'
                      ? 'Fácil'
                      : mission.difficulty == 'MEDIUM'
                          ? 'Média'
                          : 'Difícil'),
              Icons.signal_cellular_alt,
              _getDifficultyColor(mission.difficulty)),
          
          // Tipo de validação
          if (mission.validationTypeDisplay != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              'Validação',
              mission.validationTypeDisplay!,
              Icons.verified_outlined,
              AppColors.primary,
            ),
          ],
          
          // Target Info - informações consolidadas de alvos
          if (mission.targetInfo != null && mission.targetInfo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 16),
            Text(
              'Alvos',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildTargetInfoWidgets(theme, mission.targetInfo!),
          ],
          
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
  
  List<Widget> _buildTargetInfoWidgets(ThemeData theme, Map<String, dynamic> targetInfo) {
    final List<Widget> widgets = [];
    
    targetInfo.forEach((key, value) {
      if (value == null) return;
      
      IconData icon;
      Color color;
      String displayValue;
      String displayLabel;
      
      // Mapear chaves para labels e formatação apropriada
      switch (key) {
        case 'target_tps':
          icon = Icons.savings_outlined;
          color = const Color(0xFF4CAF50);
          displayValue = '$value%';
          displayLabel = 'TPS Alvo';
          break;
        case 'target_rdr':
          icon = Icons.trending_down;
          color = const Color(0xFFF44336);
          displayValue = '$value%';
          displayLabel = 'RDR Alvo';
          break;
        case 'min_ili':
          icon = Icons.account_balance_wallet;
          color = const Color(0xFF2196F3);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'ILI Mínimo';
          break;
        case 'max_ili':
          icon = Icons.account_balance_wallet;
          color = const Color(0xFF2196F3);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'ILI Máximo';
          break;
        case 'min_transactions':
          icon = Icons.receipt_long;
          color = const Color(0xFF9C27B0);
          displayValue = '$value transações';
          displayLabel = 'Transações Mínimas';
          break;
        case 'target_category':
          icon = Icons.category;
          color = const Color(0xFFFF9800);
          displayValue = 'Categoria #$value';
          displayLabel = 'Categoria Alvo';
          break;
        case 'target_reduction_percent':
          icon = Icons.arrow_downward;
          color = const Color(0xFF4CAF50);
          displayValue = '-$value%';
          displayLabel = 'Redução Necessária';
          break;
        case 'category_spending_limit':
          icon = Icons.block;
          color = const Color(0xFFF44336);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'Limite de Gastos';
          break;
        case 'savings_increase_amount':
          icon = Icons.arrow_upward;
          color = const Color(0xFF4CAF50);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'Aumento na Poupança';
          break;
        case 'goal_progress_target':
          icon = Icons.track_changes;
          color = const Color(0xFF2196F3);
          displayValue = '$value%';
          displayLabel = 'Progresso em Meta';
          break;
        case 'min_consecutive_days':
          icon = Icons.calendar_today;
          color = const Color(0xFFFF5722);
          displayValue = '$value dias';
          displayLabel = 'Dias Consecutivos';
          break;
        case 'min_daily_actions':
          icon = Icons.check_circle_outline;
          color = const Color(0xFF4CAF50);
          displayValue = '$value ações/dia';
          displayLabel = 'Ações Diárias';
          break;
        default:
          icon = Icons.info_outline;
          color = Colors.grey[400]!;
          displayValue = value.toString();
          displayLabel = key.replaceAll('_', ' ').toUpperCase();
      }
      
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
      }
      
      widgets.add(_buildInfoRow(
        theme,
        displayLabel,
        displayValue,
        icon,
        color,
      ));
    });
    
    return widgets;
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

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return const Color(0xFF4CAF50);
      case 'MEDIUM':
        return const Color(0xFFFF9800);
      case 'HARD':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  Color _getDeadlineColor(int days) {
    if (days < 0) return AppColors.alert;
    if (days <= 3) return const Color(0xFFFF9800);
    return Colors.grey[400]!;
  }
}
