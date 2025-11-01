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
import '../../../../core/widgets/indicator_insight_card.dart';
import '../../../missions/presentation/pages/missions_page.dart';
import '../../../progress/presentation/pages/progress_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../shared/widgets/section_header.dart';
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
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'homeFab',
        onPressed: _openTransactionSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova transação'),
      ),
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
                    userEmail: user?.email,
                    profile: data.profile,
                    summary: data.summary,
                    currency: _currency,
                    onProfileTap: () => _openPage(const ProfilePage()),
                    onProgressTap: () => _openPage(const ProgressPage()),
                    onTransactionsTap: () =>
                        _openPage(const TransactionsPage()),
                  ),
                  const SizedBox(height: 24),
                  _IndicatorHighlights(summary: data.summary),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: 'Insights financeiros',
                    actionLabel: 'ver detalhes',
                    onActionTap: () => _openPage(const ProgressPage()),
                  ),
                  const SizedBox(height: 12),
                  _InsightsSection(insights: data.insights),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: 'Categorias em destaque',
                    actionLabel: 'transações',
                    onActionTap: () =>
                        _openPage(const TransactionsPage()),
                  ),
                  const SizedBox(height: 12),
                  _CategoryBreakdownSection(
                    categories: data.categories,
                    currency: _currency,
                  ),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: 'Fluxo dos últimos meses',
                    actionLabel: 'ver histórico',
                    onActionTap: () =>
                        _openPage(const TransactionsPage()),
                  ),
                  const SizedBox(height: 12),
                  _CashflowChartCard(series: data.cashflow),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: 'Missões em andamento',
                    actionLabel: 'ver todas',
                    onActionTap: () => _openPage(const MissionsPage()),
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
    required this.userEmail,
    required this.profile,
    required this.summary,
    required this.currency,
    required this.onProfileTap,
    required this.onProgressTap,
    required this.onTransactionsTap,
  });

  final String userName;
  final String? userEmail;
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
    final saldoColor = saldo >= 0 ? AppColors.support : AppColors.alert;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: tokens.heroGradient,
        borderRadius: tokens.sheetRadius,
        boxShadow: tokens.deepShadow,
  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: tokens.tileRadius,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nível ${profile.level} • ${profile.experiencePoints} XP',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    if (userEmail != null && userEmail!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        userEmail!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white60),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: profile.experiencePoints / profile.nextLevelThreshold,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryTile(
                label: 'Saldo',
                value: currency.format(saldo),
                color: saldoColor,
              ),
              const SizedBox(width: 12),
              _SummaryTile(
                label: 'Receitas',
                value: currency.format(summary.totalIncome),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryTile(
                label: 'Despesas',
                value: currency.format(summary.totalExpense),
              ),
              const SizedBox(width: 12),
              _SummaryTile(
                label: 'Dívidas',
                value: currency.format(summary.totalDebt),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: onTransactionsTap,
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Transações'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onProgressTap,
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Progresso'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onProfileTap,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Ajustes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorHighlights extends StatelessWidget {
  const _IndicatorHighlights({required this.summary});

  final SummaryMetrics summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _IndicatorPill(
        label: 'TPS',
        value: '${summary.tps.toStringAsFixed(1)}%',
        description: 'Meta de poupança',
        color: AppColors.primary,
      ),
      _IndicatorPill(
        label: 'RDR',
        value: '${summary.rdr.toStringAsFixed(1)}%',
        description: 'Comprometimento de renda',
        color: AppColors.alert,
      ),
      _IndicatorPill(
        label: 'ILI',
        value: '${summary.ili.toStringAsFixed(1)} meses',
        description: 'Liquidez imediata',
        color: AppColors.support,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: 12),
              ],
            ],
          );
        }

        final children = <Widget>[];
        for (var i = 0; i < cards.length; i++) {
          children.add(Expanded(child: cards[i]));
          if (i != cards.length - 1) {
            children.add(const SizedBox(width: 12));
          }
        }
        return Row(children: children);
      },
    );
  }
}

class _IndicatorPill extends StatelessWidget {
  const _IndicatorPill({
    required this.label,
    required this.value,
    required this.description,
    required this.color,
  });

  final String label;
  final String value;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
  color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
  border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.insights});

  final Map<String, IndicatorInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const _EmptySection(
        message: 'Cadastre transações para gerar dicas personalizadas.',
      );
    }

    final cards = <Widget>[];
    if (insights.containsKey('tps')) {
      cards.add(
        IndicatorInsightCard(
          insight: insights['tps']!,
          icon: Icons.savings_rounded,
        ),
      );
    }
    if (insights.containsKey('rdr')) {
      cards.add(
        IndicatorInsightCard(
          insight: insights['rdr']!,
          icon: Icons.credit_card_rounded,
        ),
      );
    }
    if (insights.containsKey('ili')) {
      cards.add(
        IndicatorInsightCard(
          insight: insights['ili']!,
          icon: Icons.security_rounded,
        ),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      children.add(cards[i]);
      if (i != cards.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }
    return Column(children: children);
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
    AppColors.primary,
    Color(0xFF0A62D1),
    AppColors.highlight,
    Color(0xFFFFC94D),
    AppColors.support,
    AppColors.alert,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    final slices =
        (categories['EXPENSE'] ?? <CategorySlice>[])
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
      final percent = max(2.5, (slice.total / total) * 100);
      sections.add(
        PieChartSectionData(
          color: color,
          value: slice.total,
          radius: 54,
          title: '${percent.toStringAsFixed(0)}%',
          titleStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
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
            'Top categorias',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 42,
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
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (groupLabel != null)
                Text(
                  groupLabel!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
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
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              percent,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _CashflowChartCard extends StatelessWidget {
  const _CashflowChartCard({required this.series});

  final List<CashflowPoint> series;

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
    for (var i = 0; i < series.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), series[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), series[i].expense));
    }

    final months = series.map((point) => _monthLabel(point.month)).toList();

    return Container(
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
            'Fluxo mensal',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(0, series.length - 1).toDouble(),
                lineTouchData: const LineTouchData(
                  touchTooltipData: LineTouchTooltipData(),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          months[index],
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
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
                    spots: incomeSpots,
                    color: AppColors.support,
                    barWidth: 3,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    color: AppColors.alert,
                    barWidth: 3,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: theme.dividerColor),
        boxShadow: tokens.mediumShadow,
      ),
      child: Row(
        children: [
          Expanded(
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
                const SizedBox(height: 6),
                Text(
                  mission.mission.description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  '${mission.progress.toStringAsFixed(0)}% concluído',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onComplete,
            child: const Text('Concluir'),
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

    return Container(
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 6),
          Text(
            mission.description,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.military_tech_rounded,
                color: AppColors.highlight.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                '${mission.rewardPoints} XP • ${_difficultyLabel(mission.difficulty)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar missão'),
            ),
          ),
        ],
      ),
    );
  }

  String _difficultyLabel(String value) {
    switch (value) {
      case 'EASY':
        return 'fácil';
      case 'MEDIUM':
        return 'média';
      case 'HARD':
        return 'difícil';
      default:
        return value.toLowerCase();
    }
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
        color: theme.colorScheme.surface,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textSecondary),
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

