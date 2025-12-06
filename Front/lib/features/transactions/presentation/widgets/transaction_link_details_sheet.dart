import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction_link.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class TransactionLinkDetailsSheet extends StatelessWidget {
  const TransactionLinkDetailsSheet({
    super.key,
    required this.link,
    required this.currency,
    required this.onDelete,
  });

  final TransactionLinkModel link;
  final NumberFormat currency;
  final VoidCallback onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Remover vínculo',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Tem certeza que deseja remover este vínculo? Esta ação não pode ser desfeita.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinkDetailsHeader(link: link),
                  const SizedBox(height: 24),
                  LinkedAmountCard(link: link, currency: currency),
                  if (link.sourceTransaction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: TransactionInfoCard(
                        title: 'Receita utilizada',
                        transaction: link.sourceTransaction!,
                        currency: currency,
                        color: AppColors.support,
                        icon: Icons.trending_up,
                        tokens: tokens,
                      ),
                    ),
                  if (link.targetTransaction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: TransactionInfoCard(
                        title: 'Despesa paga',
                        transaction: link.targetTransaction!,
                        currency: currency,
                        color: AppColors.alert,
                        icon: Icons.trending_down,
                        tokens: tokens,
                      ),
                    ),
                  if (link.description != null && link.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: DescriptionSection(description: link.description!),
                    ),
                  const SizedBox(height: 32),
                  LinkActionButtons(
                    onDelete: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class LinkDetailsHeader extends StatelessWidget {
  const LinkDetailsHeader({super.key, required this.link});

  final TransactionLinkModel link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.link, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.linkTypeLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy - HH:mm').format(link.createdAt),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LinkedAmountCard extends StatelessWidget {
  const LinkedAmountCard({
    super.key,
    required this.link,
    required this.currency,
  });

  final TransactionLinkModel link;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Valor vinculado',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
          ),
          Text(
            currency.format(link.linkedAmount),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionInfoCard extends StatelessWidget {
  const TransactionInfoCard({
    super.key,
    required this.title,
    required this.transaction,
    required this.currency,
    required this.color,
    required this.icon,
    required this.tokens,
  });

  final String title;
  final dynamic transaction;
  final NumberFormat currency;
  final Color color;
  final IconData icon;
  final AppDecorations tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: tokens.cardRadius,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description as String,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy').format(transaction.date as DateTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                currency.format(transaction.amount as num),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DescriptionSection extends StatelessWidget {
  const DescriptionSection({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Descricao',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class LinkActionButtons extends StatelessWidget {
  const LinkActionButtons({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Fechar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remover'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alert,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
