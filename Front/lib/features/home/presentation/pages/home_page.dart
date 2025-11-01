import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/category_groups.dart';
import '../../../missions/presentation/pages/missions_page.dart';
import '../../../progress/presentation/pages/progress_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../transactions/presentation/widgets/register_transaction_sheet.dart';

const _scaffoldBackground = Color(0xFF05060A);
const _cardBackground = Color(0xFF10121D);
const _cardOutline = Color(0x14FFFFFF);
const double _sectionSpacing = 32;

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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RegisterTransactionSheet(repository: _repository),
    );

    if (created == null || !mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transação ${created.description} adicionada com sucesso.'),
        backgroundColor: AppColors.primary,
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.session?.user;

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF090B16),
              Color(0xFF05060A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DashboardData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (snapshot.hasError) {
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    children: [
                      Text(
                        'Não foi possível carregar a home agora.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _refresh,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ), 
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;
              final profile = data.profile;

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, _sectionSpacing),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _HomeHeaderBar(onSettings: _openSettings),
                          const SizedBox(height: 24),
                          _OverviewCard(
                            userName: user?.name ?? 'Bem-vindo',
                            userEmail: user?.email ?? '',
                            profile: profile,
                            summary: data.summary,
                            currency: _currency,
                            onAddTransaction: _openTransactionSheet,
                            onOpenProfile: () => _openPage(const ProfilePage()),
                            onOpenProgress: () => _openPage(const ProgressPage()),
                            onOpenTransactions: () =>
                                _openPage(const TransactionsPage()),
                          ),
                          const SizedBox(height: _sectionSpacing),
                          _CategoryCard(
                            categories: data.categories,
                            currency: _currency,
                          ),
                          const SizedBox(height: _sectionSpacing),
                          _BalanceCard(
                            points: data.cashflow,
                            currency: _currency,
                          ),
                          const SizedBox(height: _sectionSpacing),
                          _MissionsCard(
                            missions: data.activeMissions,
                            onComplete: _completeMission,
                            onOpenAll: () => _openPage(const MissionsPage()),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeaderBar extends StatelessWidget {
  const _HomeHeaderBar({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    void showSoon(String message) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => showSoon('Menu disponível em breve.'),
          icon: const Icon(Icons.menu_rounded, color: Colors.white70),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => showSoon('Notificações em desenvolvimento.'),
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Colors.white70),
            ),
            IconButton(
              onPressed: () => showSoon('Busca em desenvolvimento.'),
              icon: const Icon(Icons.search_rounded, color: Colors.white70),
            ),
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.userName,
    required this.userEmail,
    required this.profile,
    required this.summary,
    required this.currency,
    required this.onAddTransaction,
    required this.onOpenProfile,
    required this.onOpenProgress,
    required this.onOpenTransactions,
  });

  final String userName;
  final String userEmail;
  final ProfileModel profile;
  final SummaryMetrics summary;
  final NumberFormat currency;
  final VoidCallback onAddTransaction;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    final saldo = summary.totalIncome - summary.totalExpense;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _cardBackground,
            AppColors.primary.withValues(alpha: 0.36),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cardOutline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.highlight.withValues(alpha: 0.7),
                      AppColors.primary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.black.withValues(alpha: 0.65),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nível ${profile.level}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                    if (userEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white38,
                                  fontFamily: 'Montserrat',
                                ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _cardOutline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pontuação Atual',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontFamily: 'Montserrat',
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile.experiencePoints} pts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                            fontFamily: 'Montserrat',
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currency.format(saldo),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onAddTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Transação',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Receitas',
                  value: summary.totalIncome,
                  currency: currency,
                  color: AppColors.support,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  label: 'Despesas',
                  value: summary.totalExpense,
                  currency: currency,
                  color: AppColors.alert,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.person_outline,
                  label: 'Perfil',
                  onTap: onOpenProfile,
                  accent: AppColors.highlight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.bar_chart_rounded,
                  label: 'Acompanhar',
                  onTap: onOpenProgress,
                  accent: AppColors.support,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transações',
                  onTap: onOpenTransactions,
                  accent: AppColors.primary,
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
    required this.currency,
    required this.color,
  });

  final String label;
  final double value;
  final NumberFormat currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final accent = color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
  border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontFamily: 'Montserrat',
                ),
          ),
          const SizedBox(height: 6),
          Text(
            currency.format(value),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.categories, required this.currency});

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
    List<CategorySlice> slices =
        (categories['EXPENSE'] ?? <CategorySlice>[]).where((e) => e.total > 0).toList();
    if (slices.isEmpty) {
      slices = categories.values
          .expand((element) => element)
          .where((e) => e.total > 0)
          .toList();
    }

    final total = slices.fold<double>(0, (sum, slice) => sum + slice.total);
    if (total <= 0) {
      return const _EmptyState(message: 'Sem categorias para exibir ainda.');
    }

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final percent = (slice.total / total) * 100;
      sections.add(
        PieChartSectionData(
          color: _palette[i % _palette.length],
          value: slice.total,
          title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
          radius: 84,
          titleStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumo de Categorias',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _cardBackground,
                AppColors.primary.withValues(alpha: 0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardOutline),
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.2,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
                    startDegreeOffset: -90,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: List.generate(slices.length, (index) {
                  final slice = slices[index];
                  final percent = (slice.total / total) * 100;
          final groupLabel = slice.group != null
            ? CategoryGroupMetadata.labels[slice.group] ??
              slice.group!
            : null;
                  return _CategoryLegend(
                    color: _palette[index % _palette.length],
                    label: slice.name,
                    groupLabel: groupLabel,
                    value: currency.format(slice.total),
                    percent: '${percent.toStringAsFixed(0)}%',
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          groupLabel == null ? label : '$label · $groupLabel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontFamily: 'Montserrat',
              ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                fontFamily: 'Montserrat',
              ),
        ),
        const SizedBox(width: 4),
        Text(
          '($percent)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                fontFamily: 'Montserrat',
              ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.points, required this.currency});

  final List<CashflowPoint> points;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyState(
        message: 'Histórico insuficiente para exibir o gráfico.',
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final balance = points[i].income - points[i].expense;
      spots.add(FlSpot(i.toDouble(), balance));
    }

    final currentBalance = points.last.income - points.last.expense;
    final previousBalance = points.length > 1
        ? points[points.length - 2].income - points[points.length - 2].expense
        : 0.0;
    final variation = currentBalance - previousBalance;
    final variationLabel = _formatSigned(currency, variation);
    final variationPercent = previousBalance == 0
        ? null
        : (variation / previousBalance) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evolução do Saldo',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _cardBackground,
                AppColors.primary.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardOutline),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Semana passada',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                      fontFamily: 'Montserrat',
                                    ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more,
                              color: Colors.white54, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            variationLabel,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: variation >= 0
                                      ? AppColors.support
                                      : AppColors.alert,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (variationPercent != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatSignedPercent(variationPercent),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: variation >= 0
                                        ? AppColors.support
                                        : AppColors.alert,
                                    fontFamily: 'Montserrat',
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.4),
                          AppColors.primary.withValues(alpha: 0.16),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      currency.format(currentBalance),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: Colors.white12,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 6,
                              child: Text(
                                _monthLabel(points[index].month),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.white54,
                                      fontFamily: 'Montserrat',
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            if (value % 500 != 0) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 6,
                              child: Text(
                                'R\$${(value / 100).round() * 100}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.white38,
                                      fontFamily: 'Montserrat',
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 4,
                        color: AppColors.primary,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.4),
                              AppColors.primary.withValues(alpha: 0.0),
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
        ),
      ],
    );
  }

  static String _monthLabel(String raw) {
    try {
      final date = DateTime.parse('$raw-01');
      return DateFormat('MMM', 'pt_BR').format(date);
    } catch (_) {
      return raw;
    }
  }

  static String _formatSigned(NumberFormat format, double value) {
    final text = format.format(value.abs());
    if (value > 0) return '+$text';
    if (value < 0) return '-$text';
    return text;
  }

  static String _formatSignedPercent(double value) {
    final rounded = value.abs().toStringAsFixed(0);
    if (value > 0) return '+$rounded%';
    if (value < 0) return '-$rounded%';
    return '$rounded%';
  }
}

class _MissionsCard extends StatelessWidget {
  const _MissionsCard({
    required this.missions,
    required this.onComplete,
    required this.onOpenAll,
  });

  final List<MissionProgressModel> missions;
  final void Function(MissionProgressModel) onComplete;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Missões em Andamento',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                  ),
            ),
            TextButton(
              onPressed: onOpenAll,
              style: TextButton.styleFrom(foregroundColor: AppColors.highlight),
              child: const Text('Ver mais'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (missions.isEmpty)
          const _EmptyState(message: 'Nenhuma missão ativa no momento.')
        else
          Column(
            children: [
              for (final mission in missions) ...[
                _MissionTile(
                  mission: mission,
                  onComplete: () => onComplete(mission),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
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
    final progressValue = (mission.progress / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _cardBackground,
                AppColors.primary.withValues(alpha: 0.16),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
  border: Border.all(color: _cardOutline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Column(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 5,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressValue >= 1
                              ? AppColors.support
                              : AppColors.highlight,
                        ),
                      ),
                      Text(
                        '${mission.progress.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${mission.mission.rewardPoints} pts',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontFamily: 'Montserrat',
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.mission.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  mission.mission.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        fontFamily: 'Montserrat',
                      ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressValue >= 1
                        ? AppColors.support
                        : AppColors.highlight,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Duração: ${mission.mission.durationDays} dias',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                            fontFamily: 'Montserrat',
                          ),
                    ),
                    TextButton(
                      onPressed: onComplete,
                      style: TextButton.styleFrom(
                        foregroundColor: progressValue >= 1
                            ? AppColors.support
                            : AppColors.highlight,
                      ),
                      child: const Text('Concluir'),
                    ),
                  ],
                ),
              ],
            ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _cardBackground,
                AppColors.primary.withValues(alpha: 0.12),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: _cardOutline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                    fontFamily: 'Montserrat',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
