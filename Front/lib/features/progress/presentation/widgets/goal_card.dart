import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../pages/goal_details_page.dart';

/// Helper para calculos do GoalCard.
abstract final class GoalCardHelper {
  static ({String text, Color color})? getDeadlineInfo(GoalModel goal) {
    if (goal.deadline == null) return null;

    final daysRemaining = goal.daysRemaining!;
    if (daysRemaining < 0) {
      return (text: 'Prazo expirado', color: AppColors.alert);
    } else if (daysRemaining == 0) {
      return (text: 'Ultimo dia', color: AppColors.alert);
    } else if (daysRemaining <= 7) {
      return (
        text: '$daysRemaining dias restantes',
        color: const Color(0xFFFF9800),
      );
    } else {
      return (
        text: DateFormat('dd/MM/yyyy').format(goal.deadline!),
        color: Colors.grey[400]!,
      );
    }
  }
}

/// Card que exibe informacoes de uma meta financeira.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  final GoalModel goal;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  Future<void> _navigateToDetails(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalDetailsPage(
          goal: goal,
          currency: currency,
          onEdit: onEdit,
        ),
      ),
    );
    if (result == true && context.mounted) {
      onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = goal.progressPercentage.clamp(0.0, 100.0);
    final tokens = theme.extension<AppDecorations>()!;
    final isCompleted = goal.isCompleted;
    final isExpired = goal.isExpired;
    final deadlineInfo = GoalCardHelper.getDeadlineInfo(goal);

    return InkWell(
      onTap: () => _navigateToDetails(context),
      borderRadius: tokens.cardRadius,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
          boxShadow: tokens.mediumShadow,
          border: isCompleted
              ? Border.all(color: AppColors.support.withOpacity(0.3), width: 1.5)
              : isExpired
                  ? Border.all(color: AppColors.alert.withOpacity(0.3), width: 1.5)
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GoalCardHeader(goal: goal, onEdit: onEdit, onDelete: onDelete),
            const SizedBox(height: 16),
            GoalCardAmounts(goal: goal, currency: currency),
            if (goal.goalType == GoalType.expenseReduction ||
                goal.goalType == GoalType.incomeIncrease) ...[
              const SizedBox(height: 12),
              GoalTypeSpecificInfo(goal: goal, currency: currency),
            ],
            const SizedBox(height: 12),
            GoalCardProgressBar(goal: goal, isCompleted: isCompleted),
            const SizedBox(height: 12),
            GoalCardFooter(
              progressPercent: progressPercent,
              isCompleted: isCompleted,
              deadlineInfo: deadlineInfo,
            ),
            if (isCompleted) const GoalCompletedBanner(),
            if (isExpired && !isCompleted) const GoalExpiredBanner(),
          ],
        ),
      ),
    );
  }
}

/// Header do card de meta.
class GoalCardHeader extends StatelessWidget {
  const GoalCardHeader({
    super.key,
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalModel goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(goal.goalType.icon, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              GoalBadges(goal: goal),
              if (goal.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  goal.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ],
          ),
        ),
        GoalPopupMenu(onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}

/// Badges informativos da meta.
class GoalBadges extends StatelessWidget {
  const GoalBadges({super.key, required this.goal});

  final GoalModel goal;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        GoalBadge(text: goal.goalType.label, color: AppColors.primary),
      ],
    );
  }
}

/// Badge pequeno para exibir informacoes da meta.
class GoalBadge extends StatelessWidget {
  const GoalBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.backgroundColor,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Menu popup do card de meta.
class GoalPopupMenu extends StatelessWidget {
  const GoalPopupMenu({super.key, required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: const Color(0xFF2A2A2A),
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.grey[300]),
              const SizedBox(width: 8),
              Text('Editar', style: TextStyle(color: Colors.grey[300])),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: AppColors.alert),
              SizedBox(width: 8),
              Text('Remover', style: TextStyle(color: AppColors.alert)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Valores da meta (atual e alvo).
class GoalCardAmounts extends StatelessWidget {
  const GoalCardAmounts({super.key, required this.goal, required this.currency});

  final GoalModel goal;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          currency.format(goal.currentAmount),
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'de ${currency.format(goal.targetAmount)}',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
        ),
      ],
    );
  }
}

/// Informações específicas por tipo de meta
class GoalTypeSpecificInfo extends StatelessWidget {
  const GoalTypeSpecificInfo({
    super.key,
    required this.goal,
    required this.currency,
  });

  final GoalModel goal;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (goal.goalType == GoalType.expenseReduction)
            ..._buildExpenseReductionInfo(theme)
          else if (goal.goalType == GoalType.incomeIncrease)
            ..._buildIncomeIncreaseInfo(theme),
        ],
      ),
    );
  }

  List<Widget> _buildExpenseReductionInfo(ThemeData theme) {
    return [
      if (goal.targetCategoryName != null) ...[
        Row(
          children: [
            Icon(Icons.category, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              'Categoria: ${goal.targetCategoryName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
      if (goal.baselineAmount != null) ...[
        Row(
          children: [
            const Icon(Icons.trending_down, size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            Text(
              'Gastava: ${currency.format(goal.baselineAmount)}/mês',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
      Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.support),
          const SizedBox(width: 6),
          Text(
            'Redução: ${currency.format(goal.currentAmount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.support,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildIncomeIncreaseInfo(ThemeData theme) {
    return [
      if (goal.baselineAmount != null) ...[
        Row(
          children: [
            const Icon(Icons.trending_up, size: 14, color: Colors.blue),
            const SizedBox(width: 6),
            Text(
              'Ganhava: ${currency.format(goal.baselineAmount)}/mês',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
      Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.support),
          const SizedBox(width: 6),
          Text(
            'Aumento: ${currency.format(goal.currentAmount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.support,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ];
  }
}

/// Barra de progresso da meta.
class GoalCardProgressBar extends StatelessWidget {
  const GoalCardProgressBar({super.key, required this.goal, required this.isCompleted});

  final GoalModel goal;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: goal.progress,
        minHeight: 8,
        backgroundColor: const Color(0xFF2A2A2A),
        valueColor: AlwaysStoppedAnimation(
          isCompleted ? AppColors.support : AppColors.primary,
        ),
      ),
    );
  }
}

/// Footer do card com percentual e prazo.
class GoalCardFooter extends StatelessWidget {
  const GoalCardFooter({
    super.key,
    required this.progressPercent,
    required this.isCompleted,
    this.deadlineInfo,
  });

  final double progressPercent;
  final bool isCompleted;
  final ({String text, Color color})? deadlineInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.trending_up,
              color: isCompleted ? AppColors.support : AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '${progressPercent.toStringAsFixed(1)}% concluido',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCompleted ? AppColors.support : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (deadlineInfo != null)
          Row(
            children: [
              Icon(Icons.calendar_today, color: deadlineInfo!.color, size: 14),
              const SizedBox(width: 4),
              Text(
                deadlineInfo!.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: deadlineInfo!.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Banner de meta concluida.
class GoalCompletedBanner extends StatelessWidget {
  const GoalCompletedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.support.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.support.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration, color: AppColors.support, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Meta alcancada! Parabens pelo seu compromisso!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.support,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner de meta expirada.
class GoalExpiredBanner extends StatelessWidget {
  const GoalExpiredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.alert.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.alert.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.alert, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Prazo expirado. Considere ajustar sua meta ou criar uma nova.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.alert,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para exibir estado vazio quando nao ha metas.
class GoalsEmptyState extends StatelessWidget {
  const GoalsEmptyState({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
