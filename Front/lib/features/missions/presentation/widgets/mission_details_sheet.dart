import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/mission.dart';
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

  /// Verifica se deve exibir a seção de evolução de indicadores
  /// Apenas para missões que envolvem TPS, RDR ou ILI
  bool _shouldShowIndicatorsComparison() {
    final mission = widget.missionProgress.mission;
    final missionType = mission.missionType;
    
    // Missões que envolvem indicadores financeiros
    if (missionType == 'TPS_IMPROVEMENT' ||
        missionType == 'RDR_REDUCTION' ||
        missionType == 'ILI_BUILDING' ||
        missionType == 'ADVANCED') {
      return true;
    }
    
    // Verificar se tem metas de indicadores definidas
    if (mission.targetTps != null ||
        mission.targetRdr != null ||
        mission.minIli != null ||
        mission.maxIli != null) {
      return true;
    }
    
    // Para outros tipos (ONBOARDING, metas, amigos), não exibir
    return false;
  }

  /// Converte nome de ícone string para IconData
  IconData _getIconFromString(String iconName) {
    final iconsMap = {
      'trending_up': Icons.trending_up,
      'trending_down': Icons.trending_down,
      'security': Icons.security,
      'psychology': Icons.psychology,
      'shield': Icons.shield,
      'self_improvement': Icons.self_improvement,
      'rocket_launch': Icons.rocket_launch,
      'stars': Icons.stars,
      'lightbulb_outline': Icons.lightbulb_outline,
      'rocket': Icons.rocket,
      'star_rounded': Icons.star_rounded,
      'savings_outlined': Icons.savings_outlined,
      'cut': Icons.cut,
      'priority_high': Icons.priority_high,
      'handshake': Icons.handshake,
      'account_balance': Icons.account_balance,
      'shield_moon': Icons.shield_moon,
      'analytics': Icons.analytics,
      'calendar_month': Icons.calendar_month,
      'today': Icons.today,
    };
    return iconsMap[iconName] ?? Icons.info_outline;
  }

  /// Converte string hex de cor para Color
  Color _getColorFromString(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.primary;
    }
  }

  /// Fallback para impactos antigos (caso backend não tenha)
  List<Map<String, dynamic>> _getLegacyImpacts(MissionModel mission) {
    final impacts = <Map<String, dynamic>>[];
    
    switch (mission.missionType) {
      case 'TPS_IMPROVEMENT':
        impacts.addAll([
          {
            'icon': 'trending_up',
            'title': 'Aumenta sua Taxa de Poupança',
            'description': 'Você estará guardando mais dinheiro mensalmente',
            'color': '#4CAF50',
          },
          {
            'icon': 'security',
            'title': 'Melhora sua Segurança Financeira',
            'description': 'Construindo uma reserva para emergências',
            'color': '#7C4DFF',
          },
        ]);
        break;
      
      case 'RDR_REDUCTION':
        impacts.addAll([
          {
            'icon': 'trending_down',
            'title': 'Reduz Comprometimento da Renda',
            'description': 'Menos dinheiro comprometido com dívidas',
            'color': '#00BFA5',
          },
          {
            'icon': 'psychology',
            'title': 'Menos Estresse Financeiro',
            'description': 'Dívidas menores significam mais tranquilidade',
            'color': '#9C27B0',
          },
        ]);
        break;
      
      case 'ILI_BUILDING':
        impacts.addAll([
          {
            'icon': 'shield',
            'title': 'Aumenta sua Liquidez Imediata',
            'description': 'Mais meses de despesas cobertas em emergências',
            'color': '#2196F3',
          },
          {
            'icon': 'self_improvement',
            'title': 'Independência Financeira',
            'description': 'Maior capacidade de enfrentar imprevistos',
            'color': '#7C4DFF',
          },
        ]);
        break;
      
      case 'ADVANCED':
        impacts.addAll([
          {
            'icon': 'rocket_launch',
            'title': 'Nível Avançado de Controle',
            'description': 'Domínio completo das suas finanças',
            'color': '#FF9800',
          },
          {
            'icon': 'stars',
            'title': 'Maximiza Recompensas',
            'description': 'Maior ganho de pontos e progressão rápida',
            'color': '#7C4DFF',
          },
        ]);
        break;
      
      case 'ONBOARDING':
        impacts.addAll([
          {
            'icon': 'lightbulb_outline',
            'title': 'Aprenda Conceitos Fundamentais',
            'description': 'Entenda os pilares da saúde financeira',
            'color': '#9C27B0',
          },
          {
            'icon': 'rocket',
            'title': 'Comece sua Jornada',
            'description': 'Primeiros passos para transformar suas finanças',
            'color': '#7C4DFF',
          },
        ]);
        break;
    }

    // Adiciona impacto de pontos
    impacts.add({
      'icon': 'star_rounded',
      'title': '+${mission.rewardPoints} Pontos de Recompensa',
      'description': 'Avance de nível e desbloqueie novos desafios',
      'color': '#7C4DFF',
    });

    return impacts;
  }

  // Fallback para dicas baseadas no tipo de missão e progresso (será usado caso o backend não forneça)
  List<Map<String, dynamic>> _getLegacyTips(MissionModel mission, MissionProgressModel progress) {
    final List<Map<String, dynamic>> tips = [];

    // Dicas baseadas no progresso
    if (progress.progress < 25) {
      tips.add({
        'icon': Icons.rocket_launch,
        'title': 'Comece Agora!',
        'description': 'Quanto antes você começar, mais fácil será completar o ${UxStrings.challenge.toLowerCase()} no prazo.',
        'color': AppColors.primary,
        'priority': 'high',
      });
    } else if (progress.progress >= 25 && progress.progress < 50) {
      tips.add({
        'icon': Icons.speed,
        'title': 'Mantenha o Ritmo',
        'description': 'Você está no caminho certo! Continue assim para garantir o sucesso.',
        'color': AppColors.support,
        'priority': 'medium',
      });
    } else if (progress.progress >= 75 && progress.progress < 100) {
      tips.add({
        'icon': Icons.celebration,
        'title': 'Quase Lá!',
        'description': 'Falta pouco! Mantenha o foco para completar o ${UxStrings.challenge.toLowerCase()}.',
        'color': AppColors.support,
        'priority': 'low',
      });
    }

    // Dicas específicas por tipo de missão
    switch (mission.missionType) {
      case 'TPS_IMPROVEMENT':
        tips.addAll([
          {
            'icon': Icons.savings_outlined,
            'title': 'Automatize sua Poupança',
            'description': 'Configure transferências automáticas no início do mês para garantir que você poupe antes de gastar.',
            'color': const Color(0xFF4CAF50),
            'priority': 'high',
          },
          {
            'icon': Icons.cut,
            'title': 'Reduza Gastos Supérfluos',
            'description': 'Identifique e corte despesas não essenciais como assinaturas não utilizadas.',
            'color': const Color(0xFFFF9800),
            'priority': 'medium',
          },
        ]);
        break;
      
      case 'RDR_REDUCTION':
        tips.addAll([
          {
            'icon': Icons.priority_high,
            'title': 'Priorize Dívidas Caras',
            'description': 'Foque em pagar primeiro as dívidas com juros mais altos (cartão de crédito, cheque especial).',
            'color': AppColors.alert,
            'priority': 'high',
          },
          {
            'icon': Icons.handshake,
            'title': 'Negocie suas Dívidas',
            'description': 'Entre em contato com credores para renegociar taxas e prazos mais favoráveis.',
            'color': const Color(0xFF9C27B0),
            'priority': 'medium',
          },
        ]);
        break;
      
      case 'ILI_BUILDING':
        tips.addAll([
          {
            'icon': Icons.account_balance,
            'title': 'Escolha a Conta Certa',
            'description': 'Mantenha sua reserva de emergência em conta com liquidez imediata e rendimento.',
            'color': const Color(0xFF2196F3),
            'priority': 'high',
          },
          {
            'icon': Icons.shield_moon,
            'title': 'Proteja sua Reserva',
            'description': 'Use a reserva APENAS para emergências reais. Evite retiradas para gastos planejados.',
            'color': AppColors.primary,
            'priority': 'medium',
          },
        ]);
        break;
      
      case 'ADVANCED':
        tips.addAll([
          {
            'icon': Icons.analytics,
            'title': 'Analise Padrões',
            'description': 'Use a aba ${UxStrings.analysis} para identificar tendências e otimizar seus gastos.',
            'color': const Color(0xFFFF9800),
            'priority': 'medium',
          },
          {
            'icon': Icons.calendar_month,
            'title': 'Planejamento Mensal',
            'description': 'Revise e ajuste seu orçamento no início de cada mês baseado no mês anterior.',
            'color': AppColors.primary,
            'priority': 'medium',
          },
        ]);
        break;
    }

    // Dicas baseadas em streak
    if (progress.currentStreak != null && progress.currentStreak! > 0) {
      tips.add({
        'icon': Icons.local_fire_department,
        'title': 'Não Quebre sua Sequência!',
        'description': 'Você está em uma sequência de ${progress.currentStreak} dias. Continue todos os dias!',
        'color': const Color(0xFFFF5722),
        'priority': 'high',
      });
    }

    // Dica padrão se não houver outras
    if (tips.isEmpty) {
      tips.add({
        'icon': Icons.lightbulb,
        'title': 'Continue Progredindo',
        'description': 'Mantenha o foco nos requisitos do ${UxStrings.challenge.toLowerCase()} e acompanhe seu progresso diariamente.',
        'color': AppColors.primary,
        'priority': 'medium',
      });
    }

    return tips;
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.missionProgress.mission.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Badge de origem (template/AI)
                            if (widget.missionProgress.mission.source != null)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.missionProgress.mission.source == 'template'
                                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                                      : const Color(0xFF2196F3).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: widget.missionProgress.mission.source == 'template'
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFF2196F3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.missionProgress.mission.source == 'template'
                                          ? Icons.bolt
                                          : Icons.auto_awesome,
                                      size: 12,
                                      color: widget.missionProgress.mission.source == 'template'
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFF2196F3),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.missionProgress.mission.source == 'template'
                                          ? 'Template'
                                          : 'IA',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: widget.missionProgress.mission.source == 'template'
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFF2196F3),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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
                              // Nova seção de validação e streak
                              if (widget.missionProgress.mission.validationType != 'SNAPSHOT' ||
                                  widget.missionProgress.hasActiveStreak) ...[
                                const SizedBox(height: 24),
                                _buildValidationSection(theme, tokens),
                              ],
                              // Seção de requisitos detalhados
                              const SizedBox(height: 24),
                              _buildRequirementsSection(theme, tokens),
                              // Seção de impacto esperado
                              const SizedBox(height: 24),
                              _buildImpactSection(theme, tokens),
                              if (_details?['progress_breakdown'] != null) ...[
                                const SizedBox(height: 24),
                                _buildBreakdownSection(theme, tokens),
                              ],
                              // Seção de recomendações personalizadas
                              const SizedBox(height: 24),
                              _buildRecommendationsSection(theme, tokens),
                              if (_details?['progress_timeline'] != null) ...[
                                const SizedBox(height: 24),
                                _buildTimelineSection(theme, tokens),
                              ],
                              // Só exibe evolução de indicadores para missões que envolvem TPS/RDR/ILI
                              if (_shouldShowIndicatorsComparison() &&
                                  _details?['current_vs_initial'] != null) ...[
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

  Widget _buildValidationSection(ThemeData theme, AppDecorations tokens) {
    final mission = widget.missionProgress.mission;
    final progress = widget.missionProgress;

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
            'Validação e Progresso',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          
          // Tipo de validação
          _buildInfoRow(
            theme,
            'Tipo de validação',
            mission.validationTypeLabel,
            Icons.verified_outlined,
            AppColors.primary,
          ),
          
          // Streak (se aplicável)
          if (progress.hasActiveStreak || (progress.maxStreak ?? 0) > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: progress.hasActiveStreak
                    ? Border.all(color: AppColors.support.withOpacity(0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: progress.hasActiveStreak
                            ? const Color(0xFFFF6B00)
                            : Colors.grey[400],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sequência Atual',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            progress.streakDescription,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: progress.hasActiveStreak
                                  ? const Color(0xFFFF6B00)
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if ((progress.maxStreak ?? 0) > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Melhor sequência: ${progress.maxStreak} dias',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          // Dias atendendo critério
          if ((progress.daysMetCriteria ?? 0) > 0 ||
              (progress.daysViolatedCriteria ?? 0) > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if ((progress.daysMetCriteria ?? 0) > 0)
                    _buildStatColumn(
                      theme,
                      '${progress.daysMetCriteria}',
                      'Dias OK',
                      AppColors.support,
                      Icons.check_circle_outline,
                    ),
                  if ((progress.daysViolatedCriteria ?? 0) > 0)
                    _buildStatColumn(
                      theme,
                      '${progress.daysViolatedCriteria}',
                      'Violações',
                      AppColors.alert,
                      Icons.cancel_outlined,
                    ),
                ],
              ),
            ),
          ],
          
          // Última violação
          if (progress.lastViolationDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.warning_outlined, color: AppColors.alert, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Última violação: ${DateFormat('dd/MM/yyyy').format(progress.lastViolationDate!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(
      ThemeData theme, String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsSection(ThemeData theme, AppDecorations tokens) {
    final mission = widget.missionProgress.mission;
    final List<Map<String, dynamic>> requirements = [];

    // Adiciona requisitos baseados no tipo de validação
    switch (mission.validationType) {
      case 'TEMPORAL':
        if (mission.requiresConsecutiveDays == true && mission.minConsecutiveDays != null) {
          requirements.add({
            'icon': Icons.calendar_today,
            'title': 'Dias Consecutivos',
            'description': 'Mantenha os critérios por ${mission.minConsecutiveDays} dias seguidos',
            'color': AppColors.primary,
          });
        }
        break;
      
      case 'CATEGORY_REDUCTION':
        if (mission.targetCategory != null && mission.targetReductionPercent != null) {
          requirements.add({
            'icon': Icons.trending_down,
            'title': 'Redução de Categoria',
            'description': 'Reduza gastos em ${mission.targetReductionPercent}% comparado ao período base',
            'color': AppColors.support,
          });
        }
        break;
      
      case 'CATEGORY_LIMIT':
        if (mission.categorySpendingLimit != null) {
          requirements.add({
            'icon': Icons.block,
            'title': 'Limite de Gastos',
            'description': 'Não ultrapasse R\$ ${mission.categorySpendingLimit!.toStringAsFixed(2)}',
            'color': AppColors.alert,
          });
        }
        break;
      
      case 'GOAL_PROGRESS':
        if (mission.targetGoal != null && mission.goalProgressTarget != null) {
          requirements.add({
            'icon': Icons.track_changes,
            'title': 'Progresso em Meta',
            'description': 'Alcance ${mission.goalProgressTarget}% da meta',
            'color': AppColors.primary,
          });
        }
        break;
      
      case 'SAVINGS_INCREASE':
        if (mission.savingsIncreaseAmount != null) {
          requirements.add({
            'icon': Icons.savings_outlined,
            'title': 'Aumento de Poupança',
            'description': 'Aumente a poupança em R\$ ${mission.savingsIncreaseAmount!.toStringAsFixed(2)}',
            'color': AppColors.support,
          });
        }
        break;
      
      case 'CONSISTENCY':
        if (mission.requiresDailyAction == true && mission.minDailyActions != null) {
          requirements.add({
            'icon': Icons.repeat,
            'title': 'Ações Diárias',
            'description': 'Execute pelo menos ${mission.minDailyActions} ações por dia',
            'color': AppColors.primary,
          });
        }
        break;
    }

    // Adiciona requisitos de indicadores se houver
    if (mission.targetTps != null) {
      requirements.add({
        'icon': Icons.account_balance_wallet,
        'title': 'TPS Alvo',
        'description': 'Atinja ${mission.targetTps}% de Taxa de Poupança',
        'color': const Color(0xFF4CAF50),
      });
    }
    
    if (mission.targetRdr != null) {
      requirements.add({
        'icon': Icons.credit_card,
        'title': 'RDR Alvo',
        'description': 'Mantenha RDR abaixo de ${mission.targetRdr}%',
        'color': const Color(0xFFF44336),
      });
    }
    
    if (mission.minIli != null || mission.maxIli != null) {
      final minIli = mission.minIli ?? 0;
      final maxIli = mission.maxIli ?? double.infinity;
      requirements.add({
        'icon': Icons.shield,
        'title': 'ILI Alvo',
        'description': maxIli == double.infinity 
            ? 'Mantenha ILI acima de $minIli meses'
            : 'Mantenha ILI entre $minIli e $maxIli meses',
        'color': const Color(0xFF2196F3),
      });
    }
    
    if (mission.minTransactions != null) {
      requirements.add({
        'icon': Icons.receipt_long,
        'title': 'Transações Mínimas',
        'description': 'Registre pelo menos ${mission.minTransactions} transações',
        'color': const Color(0xFFFF9800),
      });
    }

    if (requirements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.checklist,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                UxStrings.challengeRequirements,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...requirements.map((req) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRequirementItem(theme, req),
          )),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(ThemeData theme, Map<String, dynamic> requirement) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (requirement['color'] as Color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              requirement['icon'] as IconData,
              color: requirement['color'] as Color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement['title'] as String,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  requirement['description'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactSection(ThemeData theme, AppDecorations tokens) {
    final mission = widget.missionProgress.mission;
    
    // Usar impacts do backend se disponível, caso contrário fallback para lógica antiga
    final List<Map<String, dynamic>> impacts = mission.impacts ?? _getLegacyImpacts(mission);

    if (impacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: AppColors.support.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.support.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.support,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Impacto ao Completar',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Veja como este ${UxStrings.challenge.toLowerCase()} vai melhorar suas finanças',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...impacts.map((impact) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildImpactItem(theme, impact),
          )),
        ],
      ),
    );
  }

  Widget _buildImpactItem(ThemeData theme, Map<String, dynamic> impact) {
    // Converter icon e color se vierem como strings do backend
    final IconData icon = impact['icon'] is String 
        ? _getIconFromString(impact['icon'] as String)
        : impact['icon'] as IconData;
    
    final Color color = impact['color'] is String
        ? _getColorFromString(impact['color'] as String)
        : impact['color'] as Color;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  impact['title'] as String,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  impact['description'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(ThemeData theme, AppDecorations tokens) {
    final mission = widget.missionProgress.mission;
    final progress = widget.missionProgress;
    
    // Usa dicas do backend ou fallback para dicas legadas
    List<Map<String, dynamic>> recommendations = mission.tips != null && mission.tips!.isNotEmpty
        ? List<Map<String, dynamic>>.from(mission.tips!)
        : _getLegacyTips(mission, progress);

    // Adiciona dicas baseadas em dias restantes (contextuais, sempre do frontend)
    if (_details?['days_remaining'] != null) {
      final daysRemaining = _details!['days_remaining'] as int;
      if (daysRemaining <= 3 && daysRemaining > 0 && progress.progress < 80) {
        recommendations.insert(0, {
          'icon': Icons.timer,
          'title': 'Prazo Crítico!',
          'description': 'Apenas $daysRemaining dias restantes. Concentre esforços para completar a tempo.',
          'color': AppColors.alert,
          'priority': 'high',
        });
      }
    }

    // Ordena por prioridade
    recommendations.sort((a, b) {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final priorityA = a['priority'] as String? ?? 'medium';
      final priorityB = b['priority'] as String? ?? 'medium';
      return priorityOrder[priorityA]!.compareTo(priorityOrder[priorityB]!);
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Dicas Personalizadas',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recomendações baseadas no seu progresso atual',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecommendationItem(theme, rec),
          )),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(ThemeData theme, Map<String, dynamic> recommendation) {
    final priority = recommendation['priority'] as String? ?? 'medium';
    final isPriority = priority == 'high';
    
    // Converter icon e color se vierem como strings do backend
    final IconData icon = recommendation['icon'] is String 
        ? _getIconFromString(recommendation['icon'] as String)
        : (recommendation['icon'] as IconData? ?? Icons.lightbulb);
    
    // Definir cor padrão com base na prioridade se não houver color definida
    Color color;
    if (recommendation['color'] != null) {
      color = recommendation['color'] is String
          ? _getColorFromString(recommendation['color'] as String)
          : recommendation['color'] as Color;
    } else {
      // Cores padrão baseadas na prioridade
      color = priority == 'high' 
          ? AppColors.alert
          : priority == 'medium'
              ? const Color(0xFFFF9800)
              : AppColors.support;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
        border: isPriority 
            ? Border.all(color: color.withOpacity(0.3), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recommendation['title'] as String,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRIORITÁRIO',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  recommendation['description'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            met ? Border.all(color: AppColors.support.withOpacity(0.3)) : null,
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
                const Icon(Icons.check_circle, color: AppColors.support, size: 20),
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
                  : AppColors.primary.withOpacity(0.2),
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
          return isPositive ? 'Despesa aumentou' : 'Despesa reduziu';
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
                      .withOpacity(0.15),
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
