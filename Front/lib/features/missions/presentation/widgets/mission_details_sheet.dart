import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/mission_constants.dart';
import '../../../../core/models/category.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/constants/user_friendly_strings.dart';

class MissionDetailsSheet extends StatefulWidget {
  final MissionProgressModel missionProgress;
  final FinanceRepository repository;
  final VoidCallback onUpdate;
  final Future<bool> Function(int, {List<int>? categoryIds}) onStart;
  final Future<bool> Function(int) onSkip;

  const MissionDetailsSheet({
    super.key,
    required this.missionProgress,
    required this.repository,
    required this.onUpdate,
    required this.onStart,
    required this.onSkip,
  });

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

  /// Mostra diálogo para seleção de categorias a monitorar
  /// Retorna lista de IDs selecionados, ou [] para "Geral" (todas), ou null se cancelar
  Future<List<int>?> _showCategorySelectionDialog() async {
    final mission = widget.missionProgress.mission;
    final typeFilter = mission.transactionTypeFilter ?? 'EXPENSE';
    
    // Determina tipo de categoria a filtrar
    final categoryType = typeFilter == 'INCOME' ? 'INCOME' : 'EXPENSE';
    
    try {
      final categories = await widget.repository.fetchCategories(type: categoryType);
      
      if (!mounted) return null;
      
      return await showModalBottomSheet<List<int>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _CategorySelectionBottomSheet(
          categories: categories,
          transactionType: typeFilter,
        ),
      );
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(context, 'Erro ao carregar categorias');
      }
      return null;
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
                              
                              if (widget.missionProgress.status == 'PENDING') ...[
                                const SizedBox(height: 32),
                                _buildActionButtons(theme),
                              ] else if (widget.missionProgress.status == 'IN_PROGRESS' || 
                                         widget.missionProgress.status == 'ACTIVE') ...[
                                const SizedBox(height: 32),
                                _buildAbandonButton(theme),
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
      
      // Skip empty lists and maps
      if (value is List && value.isEmpty) return;
      if (value is Map && value.isEmpty) return;
      
      // Filter out internal/system keys that shouldn't be shown to the user
      // Use lowercase comparison to handle case variations from the API
      const internalKeys = {
        'type', 
        'validation_type', 
        'targets', 
        'completion_criteria', 
        'reward_calculation', 
        'recurrence_days',
        'start_date',
        'end_date',
        'duration_days',
        'difficulty',
        'mission_type',
        'requires_consecutive_days',
        'min_consecutive_days',
        'user_id',
      };

      if (internalKeys.contains(key.toLowerCase())) return;
      
      IconData icon;
      Color color;
      String displayValue;
      String displayLabel;
      String? tip;
      
      switch (key) {
        case 'target_tps':
          icon = Icons.savings_outlined;
          color = const Color(0xFF4CAF50);
          displayValue = '$value%';
          displayLabel = 'Meta de Poupança (TPS)';
          tip = 'Aumente receitas ou faça aportes em categorias de Poupança/Investimento.';
          break;
        case 'target_rdr':
          icon = Icons.trending_down;
          color = const Color(0xFFF44336);
          displayValue = '$value%';
          displayLabel = 'Teto de Dívidas (RDR)';
          tip = 'Pague dívidas vinculando despesas a receitas.';
          break;
        case 'min_ili':
          icon = Icons.account_balance_wallet;
          color = const Color(0xFF2196F3);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'Reserva Mínima (ILI)';
          tip = 'Aumente sua reserva de emergência ou reduza despesas essenciais.';
          break;
        case 'max_ili':
          icon = Icons.account_balance_wallet;
          color = const Color(0xFF2196F3);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'Reserva Máxima (ILI)';
          break;
        case 'min_transactions':
          icon = Icons.receipt_long;
          color = const Color(0xFF9C27B0);
          displayValue = '$value transações';
          displayLabel = 'Total de Transações';
          break;
        case 'target_category':
          icon = Icons.category;
          color = const Color(0xFFFF9800);
          displayValue = 'Categoria #$value';
          displayLabel = 'Categoria Específica';
          break;
        case 'target_reduction_percent':
          icon = Icons.arrow_downward;
          color = const Color(0xFF4CAF50);
          displayValue = '-$value%';
          displayLabel = 'Meta de Redução';
          break;
        case 'category_spending_limit':
          icon = Icons.block;
          color = const Color(0xFFF44336);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'Teto de Gastos';
          tip = 'Evite ultrapassar este valor na categoria.';
          break;
        case 'savings_increase_amount':
          icon = Icons.arrow_upward;
          color = const Color(0xFF4CAF50);
          displayValue = 'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(value)}';
          displayLabel = 'Aportes na Poupança';
          tip = 'Registre transações em categorias do grupo Poupança.';
          break;
        // goal_progress_target removido - sistema de goals desativado
        // case 'goal_progress_target':
        //   icon = Icons.track_changes;
        //   color = const Color(0xFF2196F3);
        //   displayValue = '$value%';
        //   displayLabel = 'Progresso em Meta';
        //   break;
        // min_consecutive_days removido - lógica de dias consecutivos simplificada
        case 'min_daily_actions':
          icon = Icons.check_circle_outline;
          color = const Color(0xFF4CAF50);
          displayValue = '$value ações/dia';
          displayLabel = 'Registros Diários';
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
        tip: tip,
      ));
    });
    
    return widgets;
  }

  Widget _buildInfoRow(
      ThemeData theme, String label, String value, IconData icon, Color color,
      {String? tip}) {
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

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final mission = widget.missionProgress.mission;
              
              // Verifica se missão precisa de seleção de categorias
              final needsCategorySelection = 
                  mission.validationType == 'CATEGORY_REDUCTION' && 
                  mission.targetCategory == null;
              
              List<int>? selectedCategoryIds;
              
              if (needsCategorySelection) {
                // Mostra seletor de categorias
                selectedCategoryIds = await _showCategorySelectionDialog();
                if (selectedCategoryIds == null) {
                  // Usuário cancelou
                  return;
                }
              }
              
              // Executa a ação
              final success = await widget.onStart(
                mission.id,
                categoryIds: selectedCategoryIds,
              );
              
              // Fecha o modal
              if (mounted) {
                navigator.pop();
              }
              
              // Mostra feedback
              if (success) {
                FeedbackService.showSuccessWithMessenger(messenger, 'Desafio aceito! Boa sorte! 🎯');
              } else {
                FeedbackService.showErrorWithMessenger(messenger, 'Erro ao aceitar desafio. Tente novamente.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'ACEITAR DESAFIO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            // Captura o ScaffoldMessenger ANTES de fechar o modal
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            
            // Executa a ação primeiro
            final success = await widget.onSkip(widget.missionProgress.mission.id);
            
            // Fecha o modal
            if (mounted) {
              navigator.pop();
            }
            
            // Mostra feedback usando o messenger capturado
            if (success) {
              FeedbackService.showSuccessWithMessenger(messenger, 'Desafio pulado. Buscando novas sugestões...');
            } else {
              FeedbackService.showErrorWithMessenger(messenger, 'Erro ao pular desafio. Tente novamente.');
            }
          },
          icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
          label: Text(
            'Pular este desafio',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbandonButton(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Você aceitou este desafio. Se preferir, pode abandoná-lo e ele será removido da sua lista.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              // Captura o ScaffoldMessenger ANTES de fechar o modal
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              // Executa a ação primeiro
              final success = await widget.onSkip(widget.missionProgress.mission.id);
              
              // Fecha o modal
              if (mounted) {
                navigator.pop();
              }
              
              // Mostra feedback usando o messenger capturado
              if (success) {
                FeedbackService.showSuccessWithMessenger(messenger, 'Desafio abandonado.');
              } else {
                FeedbackService.showErrorWithMessenger(messenger, 'Erro ao abandonar desafio. Tente novamente.');
              }
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Abandonar Desafio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[300],
              side: BorderSide(color: Colors.red[300]!.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}



/// Widget de seleção de categorias para missões de variação percentual
class _CategorySelectionBottomSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final String transactionType;
  final bool hasPreviousMonthData;

  const _CategorySelectionBottomSheet({
    required this.categories,
    required this.transactionType,
    this.hasPreviousMonthData = true,
  });

  @override
  State<_CategorySelectionBottomSheet> createState() => 
      _CategorySelectionBottomSheetState();
}

class _CategorySelectionBottomSheetState 
    extends State<_CategorySelectionBottomSheet> {
  final Set<int> _selectedIds = {};
  bool _useGeneral = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = widget.transactionType == 'INCOME' 
        ? 'receitas' 
        : 'despesas';
    
    // Mensagem sobre funcionamento
    final explanationMessage = widget.hasPreviousMonthData
        ? 'O desafio irá comparar o mês atual com o mês anterior.'
        : 'Como você não tem dados do mês anterior, o desafio irá comparar o mês atual com o próximo mês.';
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Selecione as categorias',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Escolha quais $typeLabel monitorar neste desafio',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          
          // Mensagem explicativa sobre funcionamento
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    explanationMessage,
                    style: TextStyle(
                      color: Colors.blue[200],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Opção "Geral" (todas)
          _buildOptionTile(
            title: 'Geral (todas as categorias)',
            subtitle: 'Monitora todas as suas $typeLabel',
            icon: Icons.all_inclusive,
            isSelected: _useGeneral,
            onTap: () => setState(() {
              _useGeneral = true;
              _selectedIds.clear();
            }),
          ),
          
          const Divider(height: 24),
          
          // Opção "Categorias específicas"
          _buildOptionTile(
            title: 'Categorias específicas',
            subtitle: 'Selecione uma ou mais categorias',
            icon: Icons.category,
            isSelected: !_useGeneral,
            onTap: () => setState(() => _useGeneral = false),
          ),
          
          // Lista de categorias quando "específicas" selecionado
          if (!_useGeneral) ...[
            const SizedBox(height: 12),
            
            // Aviso sobre categorias
            if (widget.categories.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[300], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Você precisa ter pelo menos uma $typeLabel cadastrada para selecionar categorias específicas.',
                        style: TextStyle(
                          color: Colors.orange[200],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.categories.map((cat) {
                      final isSelected = _selectedIds.contains(cat.id);
                      return FilterChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedIds.add(cat.id);
                            } else {
                              _selectedIds.remove(cat.id);
                            }
                          });
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
          
          const SizedBox(height: 24),
          
          // Botão confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_useGeneral) {
                  Navigator.pop(context, <int>[]);
                } else if (_selectedIds.isNotEmpty) {
                  Navigator.pop(context, _selectedIds.toList());
                } else {
                  FeedbackService.showWarning(
                    context, 
                    'Selecione ao menos uma categoria',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_useGeneral 
                  ? 'CONFIRMAR (TODAS)' 
                  : 'CONFIRMAR (${_selectedIds.length} selecionadas)'),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? AppColors.primary 
                : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? AppColors.primary.withOpacity(0.1) 
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected ? AppColors.primary : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
