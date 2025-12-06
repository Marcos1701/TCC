import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

abstract final class TransactionTileHelper {
  static Color colorFor(String type) {
    switch (type) {
      case 'INCOME':
        return AppColors.support;
      case 'EXPENSE':
        return AppColors.alert;
      case 'EXPENSE_PAYMENT':
        return AppColors.highlight;
      default:
        return AppColors.primary;
    }
  }

  static IconData iconFor(String type) {
    switch (type) {
      case 'INCOME':
        return Icons.arrow_upward_rounded;
      case 'EXPENSE':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  static Color? parseCategoryColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;
    try {
      final hexColor = colorString.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
    } catch (_) {
    }
    return null;
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    required this.onTap,
    required this.onRemove,
  });

  final TransactionModel transaction;
  final NumberFormat currency;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final accent = TransactionTileHelper.colorFor(transaction.type);
    final icon = TransactionTileHelper.iconFor(transaction.type);
    final recurrenceLabel = transaction.recurrenceLabel;
    final categoryColor =
        TransactionTileHelper.parseCategoryColor(transaction.category?.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
          boxShadow: tokens.mediumShadow,
          border: categoryColor != null
              ? Border.all(color: categoryColor.withOpacity(0.3), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                TransactionIcon(accent: accent, icon: icon),
                const SizedBox(width: 14),
                Expanded(
                  child: TransactionInfo(
                    transaction: transaction,
                    categoryColor: categoryColor,
                  ),
                ),
                const SizedBox(width: 12),
                TransactionAmount(
                  transaction: transaction,
                  currency: currency,
                  accent: accent,
                ),
                const SizedBox(width: 4),
                TransactionDeleteButton(onRemove: onRemove),
              ],
            ),
            if (transaction.isRecurring && recurrenceLabel != null) ...[
              const SizedBox(height: 12),
              RecurringBadge(
                primary: recurrenceLabel,
                endDate: transaction.recurrenceEndDate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TransactionIcon extends StatelessWidget {
  const TransactionIcon({
    super.key,
    required this.accent,
    required this.icon,
  });

  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: accent, size: 24),
    );
  }
}

class TransactionInfo extends StatelessWidget {
  const TransactionInfo({
    super.key,
    required this.transaction,
    this.categoryColor,
  });

  final TransactionModel transaction;
  final Color? categoryColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          transaction.description,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (categoryColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                transaction.category?.name ?? 'Sem categoria',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TransactionAmount extends StatelessWidget {
  const TransactionAmount({
    super.key,
    required this.transaction,
    required this.currency,
    required this.accent,
  });

  final TransactionModel transaction;
  final NumberFormat currency;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          currency.format(transaction.amount),
          style: theme.textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('dd/MM/yy').format(transaction.date),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class TransactionDeleteButton extends StatelessWidget {
  const TransactionDeleteButton({super.key, required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        tooltip: 'Excluir',
        onPressed: onRemove,
        icon: Icon(Icons.delete_outline, color: Colors.grey[500]),
        iconSize: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}

class RecurringBadge extends StatelessWidget {
  const RecurringBadge({
    super.key,
    required this.primary,
    this.endDate,
  });

  final String primary;
  final DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = endDate != null
        ? 'Ate ${DateFormat('dd/MM/yy', 'pt_BR').format(endDate!)}'
        : 'Sem data final';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.repeat_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
