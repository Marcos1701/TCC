import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/goal_edit_dialog.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/simple_goal_wizard.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _cacheManager = CacheManager();
  late Future<List<GoalModel>> _future = _repository.fetchGoals();

  @override
  void initState() {
    super.initState();
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.progress)) {
      _refresh();
      _cacheManager.clearInvalidation(CacheType.progress);
    }
  }

  Future<void> _refresh() async {
    final data = await _repository.fetchGoals();
    if (!mounted) return;
    
    if (mounted) {
      setState(() {
        _future = Future.value(data);
      });
    }
  }

  Future<void> _openGoalDialog({GoalModel? goal}) async {
    final result = await GoalEditDialog.show(
      context: context,
      goal: goal,
    );

    if (result == null || !mounted) return;

    try {
      if (goal == null) {
        await _repository.createGoal(
          title: result.title,
          description: result.description,
          targetAmount: result.targetAmount,
          initialAmount: result.initialAmount,
          deadline: result.deadline,
          goalType: result.goalType.value,
        );
      } else {
        await _repository.updateGoal(
          goalId: goal.identifier,
          title: result.title,
          description: result.description,
          targetAmount: result.targetAmount,
          initialAmount: result.initialAmount,
          deadline: result.deadline,
          goalType: result.goalType.value,
        );
      }

      if (!mounted) return;
      _cacheManager.invalidateAfterGoalUpdate();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    goal == null ? 'Meta criada com sucesso!' : 'Meta atualizada!'),
              ),
            ],
          ),
          backgroundColor: AppColors.support,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Erro ao salvar meta: $e')),
            ],
          ),
          backgroundColor: AppColors.alert,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Abre o wizard simplificado de criação de metas (Dia 15-20)
  Future<void> _openSimpleGoalWizard() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleGoalWizard(),
        fullscreenDialog: true,
      ),
    );

    if (result == true && mounted) {
      _refresh();
    }
  }

  Future<void> _deleteGoal(GoalModel goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remover meta', style: TextStyle(color: Colors.white)),
        content: Text(
          'Tem certeza que quer remover "${goal.title}"?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alert,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.deleteGoal(goal.identifier);  // Usar identifier
      if (!mounted) return;
      
      // Invalida cache após deletar meta
      _cacheManager.invalidateAfterGoalUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Metas',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'progressFab',
        onPressed: () => _openSimpleGoalWizard(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Meta'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
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
                      'Não foi possível carregar as metas.',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                );
              }

              final goals = snapshot.data ?? [];

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  Text(
                    'Defina e acompanhe suas metas financeiras. Configure valores e prazos para manter o foco nos seus objetivos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (profile != null)
                    ProfileTargetsCard(profile: profile, currency: _currency),
                  if (profile != null) const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Minhas Metas',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${goals.length} ${goals.length == 1 ? 'meta' : 'metas'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (goals.isEmpty)
                    const GoalsEmptyState(
                      message:
                          'Sem metas cadastradas ainda.\nCrie uma nova meta com o botao abaixo!',
                    )
                  else
                    ...goals.map(
                      (goal) => GoalCard(
                        goal: goal,
                        currency: _currency,
                        onEdit: () => _openGoalDialog(goal: goal),
                        onDelete: () => _deleteGoal(goal),
                        onRefresh: _refresh,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
