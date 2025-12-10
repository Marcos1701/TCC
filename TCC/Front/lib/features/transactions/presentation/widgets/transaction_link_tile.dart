import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction_link.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';

class TransactionLinkTile extends StatelessWidget {
  const TransactionLinkTile({
    super.key,
    required this.link,
    required this.currency,
    required this.onTap,
  });

  final TransactionLinkModel link;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: tokens.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LinkHeader(link: link, currency: currency),
            if (link.sourceTransaction != null &&
                link.targetTransaction != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 12),
              _LinkTransactionsRow(link: link),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkHeader extends StatelessWidget {
  const _LinkHeader({
    required this.link,
    required this.currency,
  });

  final TransactionLinkModel link;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.link, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.linkTypeLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy - HH:mm').format(link.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        Text(
          currency.format(link.linkedAmount),
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _LinkTransactionsRow extends StatelessWidget {
  const _LinkTransactionsRow({required this.link});

  final TransactionLinkModel link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'De:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                link.sourceTransaction!.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                link.targetTransaction!.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
