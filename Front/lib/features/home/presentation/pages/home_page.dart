import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../leaderboard/presentation/pages/leaderboard_page.dart';
import '../../../missions/presentation/pages/missions_page.dart';
import '../../../progress/presentation/pages/progress_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../transactions/presentation/widgets/register_transaction_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late Future<DashboardData> _future = _repository.fetchDashboard();

  Future<void> _refresh() async {
    final data = await _repository.fetchDashboard();
    if (!mounted) return;
    setState(() => _future = Future.value(data));
  }

  Future<void> _openTransactionSheet() async {
    final created = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegisterTransactionSheet(
        repository: _repository,
      ),
    );

    if (created == null || !mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transação registrada com sucesso.'),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.session?.user;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, size: 24),
            const SizedBox(width: 8),
            Text(
              'GenApp',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.white),
            tooltip: 'Ranking',
            onPressed: () => _openPage(const LeaderboardPage()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openTransactionSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  children: [
                    Text(
                      'Não foi possível carregar o painel agora.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  _HomeSummaryCard(
                    userName: user?.name ?? 'Bem-vindo',
                    profile: data.profile,
                    summary: data.summary,
                    currency: _currency,
                    onProfileTap: () => _openPage(const ProfilePage()),
                    onProgressTap: () => _openPage(const ProgressPage()),
                    onTransactionsTap: () =>
                        _openPage(const TransactionsPage()),
                  ),
                  const SizedBox(height: 24),
                  // Gráfico de Evolução do Saldo
                  _BalanceEvolutionCard(
                    profile: data.profile,
                    summary: data.summary,
                    currency: _currency,
                  ),
                  const SizedBox(height: 24),
                  // Cards de Insights Personalizados
                  _InsightsSection(
                    profile: data.profile,
                    summary: data.summary,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Missões em Andamento',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openPage(const MissionsPage()),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Ver Mais'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MissionSection(
                    active: data.activeMissions,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    required this.userName,
    required this.profile,
    required this.summary,
    required this.currency,
    required this.onProfileTap,
    required this.onProgressTap,
    required this.onTransactionsTap,
  });

  final String userName;
  final ProfileModel profile;
  final SummaryMetrics summary;
  final NumberFormat currency;
  final VoidCallback onProfileTap;
  final VoidCallback onProgressTap;
  final VoidCallback onTransactionsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final saldo = summary.totalIncome - summary.totalExpense;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com foto e pontuação
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Nível ${profile.level}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'XP Atual',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${profile.experiencePoints} pts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Saldo principal
          Text(
            'Saldo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currency.format(saldo),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onTransactionsTap,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Nova Transação'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 20),
          
          // Cards de Receitas e Despesas
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A5E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.support,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Receitas',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(summary.totalIncome),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A5E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: AppColors.alert,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Despesas',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(summary.totalExpense),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Botões de ação
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.person_outline,
                  label: 'Perfil',
                  onTap: onProfileTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Metas',
                  onTap: onProgressTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transações',
                  onTap: onTransactionsTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionSection extends StatelessWidget {
  const _MissionSection({
    required this.active,
  });

  final List<MissionProgressModel> active;

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty) {
      return _EmptySection(
        message: 'Sem missões ativas no momento.\nContinue registrando transações para receber novas missões!',
      );
    }

    return Column(
      children: [
        for (final mission in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MissionTile(mission: mission),
          ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final progressValue = (mission.progress / 100).clamp(0.0, 1.0);
    
    // Calcular dias restantes
    String deadlineText = '-';
    if (mission.startedAt != null && mission.mission.durationDays > 0) {
      final endDate = mission.startedAt!.add(
        Duration(days: mission.mission.durationDays),
      );
      final daysRemaining = endDate.difference(DateTime.now()).inDays;
      deadlineText = '$daysRemaining/${mission.mission.durationDays}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge do tipo de missão
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getMissionTypeColor(mission.mission.missionType),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  mission.mission.missionTypeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              // Indicador de prazo
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: Colors.grey[400],
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$deadlineText dias',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.mission.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mission.mission.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[400],
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${mission.progress.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (mission.progress >= 100) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.support,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Missão concluída! +${mission.mission.rewardPoints} XP',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.support,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card com gráfico de evolução do saldo
class _BalanceEvolutionCard extends StatelessWidget {
  const _BalanceEvolutionCard({
    required this.profile,
    required this.summary,
    required this.currency,
  });

  final ProfileModel profile;
  final SummaryMetrics summary;
  final NumberFormat currency;

  List<FlSpot> _generateMockData() {
    // Gera dados baseados no saldo atual
    final currentBalance = summary.totalIncome - summary.totalExpense;
    
    // Cria evolução realista dos últimos 7 dias
    return List.generate(7, (index) {
      // Aumenta o saldo gradualmente até o dia atual
      final daysFactor = index / 6; // De 0.0 (dia 0) a 1.0 (dia 6)
      final previousBalance = currentBalance * (0.7 + (daysFactor * 0.3)); // De 70% (início) a 100% (hoje) do saldo atual
      return FlSpot(index.toDouble(), previousBalance > 0 ? previousBalance : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final spots = _generateMockData();
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    
    // Calcula a tendência (último valor vs primeiro)
    final trend = spots.last.y - spots.first.y;
    final trendPercent = spots.first.y > 0 ? (trend / spots.first.y) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evolução do Saldo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Últimos 7 dias',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Indicador de tendência
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: trend >= 0 
                      ? AppColors.support.withOpacity(0.2)
                      : AppColors.alert.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      trend >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: trend >= 0 ? AppColors.support : AppColors.alert,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trendPercent >= 0 ? '+' : ''}${trendPercent.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: trend >= 0 ? AppColors.support : AppColors.alert,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minY: minY * 0.9,
                maxY: maxY * 1.1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF1E1E1E),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.primary.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
                        if (value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 3,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[800]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          currency.format(spot.y),
                          theme.textTheme.bodySmall!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seção com cards de insights personalizados
class _InsightsSection extends StatelessWidget {
  const _InsightsSection({
    required this.profile,
    required this.summary,
  });

  final ProfileModel profile;
  final SummaryMetrics summary;

  List<_InsightData> _generateInsights() {
    final insights = <_InsightData>[];
    
    // Insight baseado no TPS
    if (summary.tps < 30) {
      insights.add(_InsightData(
        icon: Icons.savings_outlined,
        title: 'Melhore sua Taxa de Poupança',
        description: 'Seu TPS está em ${summary.tps.toStringAsFixed(1)}%. Tente economizar mais para alcançar 30%.',
        color: AppColors.alert,
        actionLabel: 'Ver Dicas',
      ));
    } else if (summary.tps >= 30) {
      insights.add(_InsightData(
        icon: Icons.trending_up,
        title: 'Ótima Taxa de Poupança!',
        description: 'Você está economizando ${summary.tps.toStringAsFixed(1)}% da sua renda. Continue assim!',
        color: AppColors.support,
        actionLabel: 'Ver Metas',
      ));
    }

    // Insight baseado no RDR
    if (summary.rdr > 35) {
      insights.add(_InsightData(
        icon: Icons.warning_amber_rounded,
        title: 'Atenção às Dívidas',
        description: 'Seu RDR está em ${summary.rdr.toStringAsFixed(1)}%. Reduza suas dívidas para manter abaixo de 35%.',
        color: AppColors.alert,
        actionLabel: 'Ver Dívidas',
      ));
    }

    // Insight baseado no ILI
    if (summary.ili < 3) {
      insights.add(_InsightData(
        icon: Icons.emergency,
        title: 'Crie uma Reserva de Emergência',
        description: 'Seu ILI é ${summary.ili.toStringAsFixed(1)} meses. Idealmente, tenha 6 meses de reserva para despesas essenciais.',
        color: AppColors.highlight,
        actionLabel: 'Saiba Mais',
      ));
    } else if (summary.ili >= 6) {
      insights.add(_InsightData(
        icon: Icons.shield_outlined,
        title: 'Reserva de Emergência Sólida!',
        description: 'Você tem ${summary.ili.toStringAsFixed(1)} meses de reserva. Sua segurança financeira está excelente!',
        color: AppColors.support,
        actionLabel: 'Ver Conquistas',
      ));
    }

    // Se não houver insights específicos, adiciona motivacional
    if (insights.isEmpty) {
      insights.add(_InsightData(
        icon: Icons.rocket_launch_outlined,
        title: 'Continue Progredindo!',
        description: 'Seus indicadores estão equilibrados. Continue registrando transações e completando missões!',
        color: AppColors.primary,
        actionLabel: 'Ver Missões',
      ));
    }

    return insights.take(2).toList(); // Mostra no máximo 2 insights
  }

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights Personalizados',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InsightCard(insight: insight),
            )),
      ],
    );
  }
}

class _InsightData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String actionLabel;

  _InsightData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.actionLabel,
  });
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final _InsightData insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
        border: Border.all(
          color: insight.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: insight.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              insight.icon,
              color: insight.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: insight.color,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    insight.actionLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
