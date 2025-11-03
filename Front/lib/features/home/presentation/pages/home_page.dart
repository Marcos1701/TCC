import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
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
    final created = await showModalBottomSheet<TransactionModel>(
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
      SnackBar(
        content: Text(
          'Transação "${created.description}" registrada com sucesso.',
        ),
      ),
    );
  }

  Future<void> _completeMission(MissionProgressModel progress) async {
    final session = SessionScope.of(context);
    await _repository.updateMission(
      progressId: progress.id,
      status: 'COMPLETED',
      progress: 100,
    );
    if (!mounted) return;
    await _refresh();
    await session.refreshSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missão concluída, parabéns!')),
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
                  _CategoryBreakdownSection(
                    categories: data.categories,
                    currency: _currency,
                  ),
                  const SizedBox(height: 16),
                  _CashflowChartCard(
                    series: data.cashflow,
                    currency: _currency,
                  ),
                  const SizedBox(height: 16),
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
                        child: const Text('Ver Mais'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MissionSection(
                    active: data.activeMissions,
                    recommended: data.recommendedMissions,
                    onComplete: _completeMission,
                    onStart: (id) async {
                      await _repository.startMission(id);
                      if (!mounted) return;
                      await _refresh();
                    },
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
                    'Pontuação Atual',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${profile.experiencePoints} pts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
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
            label: const Text('Transação'),
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
                      Text(
                        'Receitas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
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
                      Text(
                        'Despesas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
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
                  icon: Icons.bar_chart,
                  label: 'Acompanhar\nProgresso',
                  onTap: onProgressTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.swap_horiz,
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

class _CategoryBreakdownSection extends StatelessWidget {
  const _CategoryBreakdownSection({
    required this.categories,
    required this.currency,
  });

  final Map<String, List<CategorySlice>> categories;
  final NumberFormat currency;

  static const _palette = [
    Color(0xFFD896FF), // Roxo claro
    Color(0xFF96D4D4), // Ciano
    Color(0xFFFDB913), // Amarelo
    Color(0xFFFFA07A), // Laranja claro
    Color(0xFF87CEEB), // Azul céu
    Color(0xFFFF6B9D), // Rosa
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    final slices = (categories['EXPENSE'] ?? <CategorySlice>[])
        .where((slice) => slice.total > 0)
        .toList();
    if (slices.isEmpty) {
      return const _EmptySection(
        message: 'Ainda não há despesas categorizadas neste período.',
      );
    }

    final total = slices.fold<double>(0, (sum, slice) => sum + slice.total);
    if (total <= 0) {
      return const _EmptySection(
        message: 'Cadastre despesas para visualizar o detalhamento.',
      );
    }

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final color = _palette[i % _palette.length];
      final percent = (slice.total / total) * 100;
      sections.add(
        PieChartSectionData(
          color: color,
          value: slice.total,
          radius: 60,
          title: percent >= 5 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

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
          Text(
            'Resumo de Categorias',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                startDegreeOffset: -90,
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < slices.length; i++) ...[
            _CategoryLegend(
              color: _palette[i % _palette.length],
              label: slices[i].name,
              groupLabel: _formatGroupName(slices[i].group),
              value: currency.format(slices[i].total),
              percent:
                  '${((slices[i].total / total) * 100).toStringAsFixed(1)}%',
            ),
            if (i != slices.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String? _formatGroupName(String? group) {
    if (group == null || group.isEmpty) return null;
    final normalized = group.toLowerCase().replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({
    required this.color,
    required this.label,
    this.groupLabel,
    required this.value,
    required this.percent,
  });

  final Color color;
  final String label;
  final String? groupLabel;
  final String value;
  final String percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (groupLabel != null)
                Text(
                  groupLabel!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[400]),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              percent,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey[400]),
            ),
          ],
        ),
      ],
    );
  }
}

class _CashflowChartCard extends StatelessWidget {
  const _CashflowChartCard({
    required this.series,
    required this.currency,
  });

  final List<CashflowPoint> series;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    if (series.isEmpty) {
      return const _EmptySection(
        message: 'Sem histórico recente. Registre transações para ver o fluxo.',
      );
    }

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final balanceSpots = <FlSpot>[];
    double maxY = 0;
    double minY = 0;

    for (var i = 0; i < series.length; i++) {
      final balance = series[i].income - series[i].expense;
      incomeSpots.add(FlSpot(i.toDouble(), series[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), series[i].expense));
      balanceSpots.add(FlSpot(i.toDouble(), balance));
      maxY = max(maxY, balance);
      minY = min(minY, balance);
    }

    final months = series.map((point) => _monthLabel(point.month)).toList();

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
          Text(
            'Evolução do Saldo',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Semana Passada',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Mostrar variação
          if (series.isNotEmpty && series.length >= 2) ...[
            Builder(
              builder: (context) {
                final last = series.last.income - series.last.expense;
                final previous = series[series.length - 2].income - 
                                series[series.length - 2].expense;
                final diff = last - previous;
                final percentChange = previous != 0 
                    ? (diff / previous.abs() * 100) 
                    : 0.0;
                final isPositive = diff >= 0;
                
                return Text(
                  '${isPositive ? '+' : ''}${currency.format(diff)} (${percentChange.toStringAsFixed(0)}%)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isPositive ? AppColors.support : AppColors.alert,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(0, series.length - 1).toDouble(),
                minY: minY - (maxY - minY) * 0.1,
                maxY: maxY + (maxY - minY) * 0.1,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF2A2A2A),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final monthIndex = spot.x.toInt();
                        return LineTooltipItem(
                          '${currency.format(spot.y)}\n${months[monthIndex]}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 5,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFF2A2A2A),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            months[index],
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: balanceSpots,
                    color: AppColors.support,
                    barWidth: 3,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.support.withValues(alpha: 0.3),
                          AppColors.support.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(String raw) {
    try {
      final date = DateFormat('yyyy-MM').parse(raw);
      return DateFormat('MMM', 'pt_BR').format(date);
    } catch (_) {
      return raw;
    }
  }
}

class _MissionSection extends StatelessWidget {
  const _MissionSection({
    required this.active,
    required this.recommended,
    required this.onComplete,
    required this.onStart,
  });

  final List<MissionProgressModel> active;
  final List<MissionModel> recommended;
  final void Function(MissionProgressModel) onComplete;
  final Future<void> Function(int) onStart;

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty && recommended.isEmpty) {
      return const _EmptySection(
        message: 'Sem missões no momento. Ative recomendações para avançar.',
      );
    }

    return Column(
      children: [
        for (final mission in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MissionTile(
              mission: mission,
              onComplete: () => onComplete(mission),
            ),
          ),
        if (recommended.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sugestões para começar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          for (final mission in recommended)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecommendedMissionCard(
                mission: mission,
                onStart: () => onStart(mission.id),
              ),
            ),
        ],
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission, required this.onComplete});

  final MissionProgressModel mission;
  final VoidCallback onComplete;

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  deadlineText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedMissionCard extends StatelessWidget {
  const _RecommendedMissionCard({required this.mission, required this.onStart});

  final MissionModel mission;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    
    // Calcular prazo da missão
    String deadlineText = '-';
    if (mission.durationDays > 0) {
      deadlineText = '0/${mission.durationDays}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              shape: BoxShape.circle,
            ),
            child: Text(
              deadlineText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mission.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
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
