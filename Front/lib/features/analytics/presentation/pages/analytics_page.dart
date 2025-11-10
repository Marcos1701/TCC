import 'package:flutter/material.dart';
import '../../../../core/models/analytics.dart';
import '../../../dashboard/data/dashboard_service.dart';

/// Tela de Analytics Avançados
/// 
/// Exibe evolução do usuário, padrões de categoria, progressão de tier e distribuição de missões
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<AnalyticsData> _analyticsFuture;
  final DashboardService _service = DashboardService();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    setState(() {
      _analyticsFuture = _service.getAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: FutureBuilder<AnalyticsData>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar analytics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadAnalytics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('Sem dados disponíveis'),
            );
          }

          final analytics = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              _loadAnalytics();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTierCard(analytics.comprehensiveContext.tier),
                const SizedBox(height: 16),
                _buildEvolutionCard(analytics.comprehensiveContext.evolution),
                const SizedBox(height: 16),
                _buildCategoryPatternsCard(analytics.categoryPatterns),
                const SizedBox(height: 16),
                _buildMissionDistributionCard(analytics.missionDistribution),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTierCard(TierInfo tier) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getTierIcon(tier.tier),
                  size: 32,
                  color: _getTierColor(tier.tier),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faixa: ${_getTierName(tier.tier)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tier.tierDescription,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Progresso do nível
            Text(
              'Nível ${tier.level}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: tier.xpProgressInLevel / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tier.xp} XP',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${tier.nextLevelXp} XP',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Faltam ${tier.xpNeeded} XP para o próximo nível',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            
            const SizedBox(height: 16),
            
            // Progresso no tier
            const Text(
              'Progresso no Tier',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: tier.tierProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getTierColor(tier.tier),
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tier.tierProgress.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (tier.nextTier != null)
                  Text(
                    'Próximo: ${_getTierName(tier.nextTier!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionCard(EvolutionData evolution) {
    if (!evolution.hasData) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text('Dados de evolução insuficientes'),
              const SizedBox(height: 4),
              Text(
                'Continue registrando suas transações',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolução (${evolution.periodDays} dias)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (evolution.tps != null) ...[
              _buildIndicatorRow('TPS - Taxa de Poupança', evolution.tps!),
              const Divider(height: 24),
            ],
            if (evolution.rdr != null) ...[
              _buildIndicatorRow('RDR - Razão de Dívida', evolution.rdr!),
              const Divider(height: 24),
            ],
            if (evolution.ili != null) ...[
              _buildIndicatorRow('ILI - Índice de Liquidez', evolution.ili!),
            ],
            
            if (evolution.consistency != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Consistência
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Consistência',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${evolution.consistency!.rate.toStringAsFixed(1)}% (${evolution.consistency!.daysRegistered}/${evolution.consistency!.totalDays} dias)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  CircularProgressIndicator(
                    value: evolution.consistency!.rate / 100,
                    backgroundColor: Colors.grey[300],
                    strokeWidth: 4,
                  ),
                ],
              ),
            ],
            
            if (evolution.problems.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Pontos de Atenção',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...evolution.problems.map((p) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            
            if (evolution.strengths.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Pontos Fortes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...evolution.strengths.map((s) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorRow(String name, IndicatorEvolution indicator) {
    IconData trendIcon;
    Color trendColor;
    
    switch (indicator.trend) {
      case 'crescente':
        trendIcon = Icons.trending_up;
        trendColor = Colors.green;
        break;
      case 'decrescente':
        trendIcon = Icons.trending_down;
        trendColor = Colors.red;
        break;
      default:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.grey;
    }

    return Row(
      children: [
        Icon(trendIcon, color: trendColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Média: ${indicator.average.toStringAsFixed(1)} | Atual: ${indicator.last.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                'Min: ${indicator.min.toStringAsFixed(1)} | Max: ${indicator.max.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Chip(
          label: Text(
            indicator.trend,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          backgroundColor: trendColor.withOpacity(0.1),
          labelStyle: TextStyle(color: trendColor),
        ),
      ],
    );
  }

  Widget _buildCategoryPatternsCard(CategoryPatternsAnalysis patterns) {
    if (!patterns.hasData || patterns.recommendations.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.category_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text('Sem recomendações de categoria'),
              const SizedBox(height: 4),
              Text(
                'Continue registrando transações em diferentes categorias',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categorias para Melhorar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Baseado em ${patterns.periodDays} dias de análise',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...patterns.recommendations.take(5).map((rec) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: _getPriorityColor(rec.priority).withOpacity(0.2),
                child: Icon(
                  rec.priority == 'HIGH'
                      ? Icons.priority_high
                      : rec.priority == 'MEDIUM'
                          ? Icons.info_outline
                          : Icons.lightbulb_outline,
                  color: _getPriorityColor(rec.priority),
                ),
              ),
              title: Text(
                rec.category,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(rec.reason),
                  if (rec.suggestedLimit != null)
                    Text(
                      'Limite sugerido: R\$ ${rec.suggestedLimit!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              trailing: Chip(
                label: Text(
                  rec.priority,
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: _getPriorityColor(rec.priority).withOpacity(0.2),
                labelStyle: TextStyle(color: _getPriorityColor(rec.priority)),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionDistributionCard(MissionDistributionAnalysis distribution) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Suas Missões',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMissionStat(
                  'Total',
                  distribution.totalMissions,
                  Colors.blue,
                  Icons.assignment,
                ),
                _buildMissionStat(
                  'Ativas',
                  distribution.activeMissions,
                  Colors.orange,
                  Icons.rocket_launch,
                ),
                _buildMissionStat(
                  'Concluídas',
                  distribution.completedMissions,
                  Colors.green,
                  Icons.check_circle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionStat(String label, int value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Helpers
  
  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'BEGINNER':
        return Icons.school;
      case 'INTERMEDIATE':
        return Icons.trending_up;
      case 'ADVANCED':
        return Icons.emoji_events;
      default:
        return Icons.person;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'BEGINNER':
        return Colors.blue;
      case 'INTERMEDIATE':
        return Colors.orange;
      case 'ADVANCED':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTierName(String tier) {
    switch (tier) {
      case 'BEGINNER':
        return 'Iniciante';
      case 'INTERMEDIATE':
        return 'Intermediário';
      case 'ADVANCED':
        return 'Avançado';
      default:
        return tier;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
