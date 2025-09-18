import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/indicator_insight_card.dart';
import '../../../shared/widgets/section_header.dart';

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
    if (mounted) {
      setState(() => _future = Future.value(data));
    }
  }

  Future<void> _startMission(int missionId) async {
    await _repository.startMission(missionId);
    if (!mounted) return;
    await _refresh();
    await SessionScope.of(context).refreshSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missão ativada, manda ver!')),
    );
  }

  Future<void> _completeMission(MissionProgressModel progress) async {
    await _repository.updateMission(
      progressId: progress.id,
      status: 'COMPLETED',
      progress: 100,
    );
    if (!mounted) return;
    await _refresh();
    await SessionScope.of(context).refreshSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missão concluída, parabéns!')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  'Não rolou carregar o painel agora.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Tentar de novo'),
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final saldo = data.summary.totalIncome - data.summary.totalExpense;
          final economia = data.summary.totalIncome > 0
              ? data.summary.totalIncome - data.summary.totalExpense
              : 0;

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Header(profile: data.profile, saldo: saldo, currency: _currency),
                    const SizedBox(height: 24),
                    _buildMetrics(data, economia),
                    ..._buildInsights(data),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: 'Resumo das categorias',
                      actionLabel: 'ver todas',
                      onActionTap: _refresh,
                    ),
                    const SizedBox(height: 16),
                    _CategoryBreakdownWidget(data: data, currency: _currency),
                    const SizedBox(height: 28),
                    const SectionHeader(
                      title: 'Fluxo dos últimos meses',
                      actionLabel: 'atualizar',
                      onActionTap: _noop,
                    ),
                    const SizedBox(height: 16),
                    _CashflowChart(points: data.cashflow),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: 'Missões ativas',
                      actionLabel: 'atualizar',
                      onActionTap: _refresh,
                    ),
                    const SizedBox(height: 12),
                    ...data.activeMissions.map(
                      (mission) => _MissionProgressCard(
                        mission: mission,
                        onComplete: () => _completeMission(mission),
                      ),
                    ),
                    if (data.activeMissions.isEmpty)
                      _EmptyState(
                        message: 'Nenhuma missão ativa. Bora pegar uma nova?',
                      ),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: 'Sugestões pra agora',
                      actionLabel: 'mais',
                      onActionTap: _refresh,
                    ),
                    const SizedBox(height: 12),
                    ...data.recommendedMissions.map(
                      (mission) => _MissionSuggestionCard(
                        mission: mission,
                        onStart: () => _startMission(mission.id),
                      ),
                    ),
                    if (data.recommendedMissions.isEmpty)
                      _EmptyState(
                        message: 'Sem sugestões novas por enquanto.',
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

  Widget _buildMetrics(DashboardData data, double economia) {
    final resumo = data.summary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 640;
        final width = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: width,
              child: MetricCard(
                title: 'Saldo atual',
                value: _currency.format(resumo.totalIncome - resumo.totalExpense),
                subtitle:
                    'Receitas ${_currency.format(resumo.totalIncome)} · Despesas ${_currency.format(resumo.totalExpense)}',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            SizedBox(
              width: width,
              child: MetricCard(
                title: 'Economia do mês',
                value: _currency.format(economia),
                subtitle: 'TPS ${resumo.tps.toStringAsFixed(1)}% · RDR ${resumo.rdr.toStringAsFixed(1)}%',
                icon: Icons.trending_up_rounded,
                color: AppColors.secondary,
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildInsights(DashboardData data) {
    if (data.insights.isEmpty) return const [];
    final tps = data.insights['tps'];
    final rdr = data.insights['rdr'];
    return [
      const SectionHeader(
        title: 'Diagnóstico financeiro',
        actionLabel: 'atualizar',
        onActionTap: _noop,
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 640;
          final width = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (tps != null)
                SizedBox(
                  width: width,
                  child: IndicatorInsightCard(
                    insight: tps,
                    icon: Icons.savings_rounded,
                  ),
                ),
              if (rdr != null)
                SizedBox(
                  width: width,
                  child: IndicatorInsightCard(
                    insight: rdr,
                    icon: Icons.credit_card_rounded,
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.saldo,
    required this.currency,
  });

  final ProfileModel profile;
  final double saldo;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D6FFF), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.18),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nível ${profile.level}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Meta TPS ${profile.targetTps}% · Meta RDR ${profile.targetRdr}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Saldo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currency.format(saldo),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: profile.experiencePoints / profile.nextLevelThreshold,
            minHeight: 10,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${profile.experiencePoints} / ${profile.nextLevelThreshold} XP',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownWidget extends StatelessWidget {
  const _CategoryBreakdownWidget({required this.data, required this.currency});

  final DashboardData data;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = data.categories['EXPENSE'] ?? [];
    final incomes = data.categories['INCOME'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (incomes.isNotEmpty) ...[
          Text('Receitas', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          ...incomes.map(
            (slice) => _CategoryTile(name: slice.name, value: currency.format(slice.total), color: AppColors.primary),
          ),
          const SizedBox(height: 16),
        ],
        Text('Despesas', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        if (expenses.isEmpty)
          const _EmptyState(message: 'Sem despesas categorizadas por enquanto.')
        else
          ...expenses.map(
            (slice) => _CategoryTile(name: slice.name, value: currency.format(slice.total), color: AppColors.secondary),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.name, required this.value, required this.color});

  final String name;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CashflowChart extends StatelessWidget {
  const _CashflowChart({required this.points});

  final List<CashflowPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyState(message: 'Ainda não tem histórico suficiente.');
    }

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (var i = 0; i < points.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), points[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), points[i].expense));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: _leftTitle),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) return const SizedBox.shrink();
                  final month = points[index].month.split('-');
                  return Text('${month[1]}/${month[0].substring(2)}', style: const TextStyle(color: Colors.white70, fontSize: 10));
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: incomeSpots,
              color: AppColors.primary,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: expenseSpots,
              color: AppColors.secondary,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftTitle(double value, TitleMeta meta) {
    if (value % 1000 != 0) return const SizedBox.shrink();
    return Text('R\$${value ~/ 1000}k', style: const TextStyle(color: Colors.white54, fontSize: 10));
  }
}

class _MissionProgressCard extends StatelessWidget {
  const _MissionProgressCard({required this.mission, required this.onComplete});

  final MissionProgressModel mission;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mission.mission.title,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            mission.mission.description,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: mission.progress.clamp(0, 100) / 100,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${mission.progress.toStringAsFixed(0)}% • ${mission.mission.rewardPoints} XP',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              TextButton(
                onPressed: onComplete,
                child: const Text('Concluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissionSuggestionCard extends StatelessWidget {
  const _MissionSuggestionCard({required this.mission, required this.onStart});

  final MissionModel mission;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mission.title,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            mission.description,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${mission.rewardPoints} XP • ${mission.durationDays} dias',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              ElevatedButton(
                onPressed: onStart,
                child: const Text('Aceitar'),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}
