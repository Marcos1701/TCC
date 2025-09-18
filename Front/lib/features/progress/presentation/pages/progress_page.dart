import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/indicator_insight_card.dart';
import '../../../shared/widgets/section_header.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late Future<_ProgressPayload> _future = _load();

  Future<_ProgressPayload> _load() async {
    final dashboardFuture = _repository.fetchDashboard();
    final goalsFuture = _repository.fetchGoals();
    final dashboard = await dashboardFuture;
    final goals = await goalsFuture;
    return _ProgressPayload(dashboard: dashboard, goals: goals);
  }

  Future<void> _refresh() async {
    final payload = await _load();
    if (mounted) {
      setState(() => _future = Future.value(payload));
    }
  }

  Future<void> _openGoalDialog({GoalModel? goal}) async {
    final titleController = TextEditingController(text: goal?.title ?? '');
    final descriptionController = TextEditingController(text: goal?.description ?? '');
    final targetController = TextEditingController(
      text: goal != null ? goal.targetAmount.toStringAsFixed(2) : '',
    );
    final currentController = TextEditingController(
      text: goal != null ? goal.currentAmount.toStringAsFixed(2) : '',
    );
    DateTime? deadline = goal?.deadline;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(goal == null ? 'Nova meta' : 'Editar meta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
              ),
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor alvo (ex: 5000)'),
              ),
              TextField(
                controller: currentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor atual (ex: 1200)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deadline == null
                          ? 'Sem prazo definido'
                          : 'Prazo: ${DateFormat('dd/MM/yyyy').format(deadline)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadline ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => deadline = picked);
                      }
                    },
                    child: const Text('Escolher prazo'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (confirmed != true) return;

    final target = double.tryParse(targetController.text.replaceAll(',', '.')) ?? 0;
    final current = double.tryParse(currentController.text.replaceAll(',', '.')) ?? 0;

    if (goal == null) {
      await _repository.createGoal(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        targetAmount: target,
        currentAmount: current,
        deadline: deadline,
      );
    } else {
      await _repository.updateGoal(
        goalId: goal.id,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        targetAmount: target,
        currentAmount: current,
        deadline: deadline,
      );
    }

    if (!mounted) return;
    await _refresh();
  }

  Future<void> _deleteGoal(GoalModel goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remover meta'),
        content: Text('Tem certeza que quer remover "${goal.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.deleteGoal(goal.id);
      if (!mounted) return;
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openGoalDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: FutureBuilder<_ProgressPayload>(
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
                    'Não deu pra carregar as metas agora.',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _refresh, child: const Text('Tentar de novo')),
                ],
              );
            }

            final payload = snapshot.data!;
            final goals = payload.goals;
            final dashboard = payload.dashboard;
            final profile = dashboard.profile;
            final tpsInsight = dashboard.insights['tps'];
            final rdrInsight = dashboard.insights['rdr'];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              children: [
                Text(
                  'Acompanhamento',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileTargetsCard(profile: profile, currency: _currency),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Histórico dos índices',
                  actionLabel: 'atualizar',
                  onActionTap: _refresh,
                ),
                const SizedBox(height: 12),
                if (dashboard.cashflow.isEmpty)
                  const _EmptyState(
                    message: 'Sem movimentação suficiente pra gerar o histórico.',
                  )
                else
                  _IndicatorHistoryChart(points: dashboard.cashflow),
                const SizedBox(height: 24),
                if (tpsInsight != null || rdrInsight != null) ...[
                  SectionHeader(
                    title: 'Diagnóstico rápido',
                    actionLabel: 'atualizar',
                    onActionTap: _refresh,
                  ),
                  const SizedBox(height: 12),
                  if (tpsInsight != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: IndicatorInsightCard(
                        insight: tpsInsight,
                        icon: Icons.savings_outlined,
                      ),
                    ),
                  if (rdrInsight != null)
                    IndicatorInsightCard(
                      insight: rdrInsight,
                      icon: Icons.trending_down_outlined,
                    ),
                  const SizedBox(height: 24),
                ],
                SectionHeader(
                  title: 'Metas financeiras',
                  actionLabel: 'atualizar',
                  onActionTap: _refresh,
                ),
                const SizedBox(height: 12),
                if (goals.isEmpty)
                  const _EmptyState(message: 'Sem metas ainda. Crie uma nova com o botão +.'),
                ...goals.map(
                  (goal) => _GoalCard(
                    goal: goal,
                    currency: _currency,
                    onEdit: () => _openGoalDialog(goal: goal),
                    onDelete: () => _deleteGoal(goal),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressPayload {
  const _ProgressPayload({required this.dashboard, required this.goals});

  final DashboardData dashboard;
  final List<GoalModel> goals;
}

class _IndicatorHistoryChart extends StatelessWidget {
  const _IndicatorHistoryChart({required this.points});

  final List<CashflowPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = points
        .map((point) => DateFormat('yyyy-MM').parse(point.month))
        .map((date) => DateFormat('MMM/yy', 'pt_BR').format(date))
        .toList();

    final tpsSpots = List.generate(
      points.length,
      (index) => FlSpot(index.toDouble(), points[index].tps),
    );
    final rdrSpots = List.generate(
      points.length,
      (index) => FlSpot(index.toDouble(), points[index].rdr),
    );

    final maxValue = points.fold<double>(
      0,
      (previousValue, point) =>
          math.max(previousValue, math.max(point.tps, point.rdr)),
    );
    final maxY = math.max(10, (maxValue / 10).ceil() * 10).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: true,
                  verticalInterval: 1,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white10,
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.white10,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            months[index].toUpperCase(),
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppColors.surfaceAlt,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final label = spot.barIndex == 0 ? 'TPS' : 'RDR';
                        final monthIndex = spot.x.round().clamp(0, months.length - 1);
                        final monthLabel = months[monthIndex];
                        return LineTooltipItem(
                          '$label: ${spot.y.toStringAsFixed(1)}%',
                          theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: '\n$monthLabel',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: tpsSpots,
                    color: AppColors.primary,
                    isCurved: true,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.12),
                    ),
                  ),
                  LineChartBarData(
                    spots: rdrSpots,
                    color: AppColors.secondary,
                    isCurved: true,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.secondary.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              _LegendIndicator(color: AppColors.primary, label: 'TPS'),
              SizedBox(width: 18),
              _LegendIndicator(color: AppColors.secondary, label: 'RDR'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendIndicator extends StatelessWidget {
  const _LegendIndicator({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _ProfileTargetsCard extends StatelessWidget {
  const _ProfileTargetsCard({required this.profile, required this.currency});

  final ProfileModel profile;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xpTarget = profile.nextLevelThreshold <= 0 ? 1 : profile.nextLevelThreshold;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Missão pessoal',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Nível ${profile.level} • ${profile.experiencePoints} XP',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: profile.experiencePoints / xpTarget,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'TPS alvo: ${profile.targetTps}% • RDR alvo: ${profile.targetRdr}%',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalModel goal;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = (goal.progress * 100).clamp(0, 100);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surface,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Remover')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (goal.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                goal.description,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          Text(
            '${currency.format(goal.currentAmount)} de ${currency.format(goal.targetAmount)}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          if (goal.deadline != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Prazo: ${DateFormat('dd/MM/yyyy').format(goal.deadline!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: goal.progress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            '${progressPercent.toStringAsFixed(1)}% concluído',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
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
      padding: const EdgeInsets.all(20),
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
