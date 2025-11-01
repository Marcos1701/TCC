import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../shared/widgets/section_header.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late Future<List<GoalModel>> _future = _repository.fetchGoals();

  Future<void> _refresh() async {
    final data = await _repository.fetchGoals();
    if (!mounted) return;
    setState(() => _future = Future.value(data));
  }

  Future<void> _openGoalDialog({GoalModel? goal}) async {
    final titleController = TextEditingController(text: goal?.title ?? '');
    final descriptionController =
        TextEditingController(text: goal?.description ?? '');
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
                decoration:
                    const InputDecoration(labelText: 'Descrição (opcional)'),
              ),
              TextField(
                controller: targetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Valor alvo (ex: 5000)'),
              ),
              TextField(
                controller: currentController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Valor atual (ex: 1200)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deadline == null
                          ? 'Sem prazo definido'
                          : 'Prazo: ${DateFormat('dd/MM/yyyy').format(deadline!)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadline ?? DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        deadline = picked;
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    );

    if (confirmed != true) return;

    final target =
        double.tryParse(targetController.text.replaceAll(',', '.')) ?? 0;
    final current =
        double.tryParse(currentController.text.replaceAll(',', '.')) ?? 0;

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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'progressFab',
        onPressed: () => _openGoalDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova meta'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<GoalModel>>(
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
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _refresh, child: const Text('Tentar de novo')),
                ],
              );
            }

            final goals = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              children: [
                Text(
                  'Acompanhamento',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Veja seus indicadores e metas financeiras em um só lugar.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                if (profile != null)
                  _ProfileTargetsCard(profile: profile, currency: _currency),
                if (profile != null) const SizedBox(height: 28),
                SectionHeader(
                  title: 'Metas financeiras',
                  actionLabel: 'atualizar',
                  onActionTap: _refresh,
                ),
                const SizedBox(height: 12),
                if (goals.isEmpty)
                  const _EmptyState(
                      message:
                          'Sem metas ainda. Crie uma nova com o botão acima.')
                else
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

class _ProfileTargetsCard extends StatelessWidget {
  const _ProfileTargetsCard({required this.profile, required this.currency});

  final ProfileModel profile;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: tokens.heroGradient,
        borderRadius: tokens.sheetRadius,
        boxShadow: tokens.deepShadow,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Missão pessoal',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Nível ${profile.level} • ${profile.experiencePoints} XP',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: profile.experiencePoints / profile.nextLevelThreshold,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'TPS alvo: ${profile.targetTps}% • RDR alvo: ${profile.targetRdr}% • ILI alvo: ${profile.targetIli.toStringAsFixed(1)} meses',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
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
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
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
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              goal.description,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${currency.format(goal.currentAmount)} de ${currency.format(goal.targetAmount)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (goal.deadline != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Prazo: ${DateFormat('dd/MM/yyyy').format(goal.deadline!)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: goal.progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.secondaryContainer,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '${progressPercent.toStringAsFixed(1)}% concluído',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
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
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: tokens.tileRadius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
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
