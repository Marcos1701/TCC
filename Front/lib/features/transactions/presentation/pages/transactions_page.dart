import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/category_groups.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../presentation/widgets/register_transaction_sheet.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  String? _filter;
  late Future<List<TransactionModel>> _future = _repository.fetchTransactions();

  Future<void> _refresh() async {
    final data = await _repository.fetchTransactions(type: _filter);
    if (!mounted) return;
    setState(() => _future = Future.value(data));
  }

  Future<void> _openSheet() async {
    final created = await showModalBottomSheet<TransactionModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RegisterTransactionSheet(repository: _repository),
    );

    if (created == null) return;
    await _refresh();
    if (!mounted) return;
    _showFeedback('Transação ${created.description} adicionada com sucesso.');
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    await _repository.deleteTransaction(transaction.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    _showFeedback('Transação ${transaction.description} removida.',
        error: false);
  }

  void _applyFilter(String? type) {
    setState(() {
      _filter = type;
      _future = _repository.fetchTransactions(type: _filter);
    });
  }

  void _showFeedback(String message, {bool error = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.alert : theme.colorScheme.primary,
      ),
    );
  }

  Map<String, double> _buildTotals(List<TransactionModel> transactions) {
    final totals = <String, double>{
      'INCOME': 0,
      'EXPENSE': 0,
      'DEBT_PAYMENT': 0,
    };
    for (final tx in transactions) {
      totals.update(tx.type, (value) => value + tx.amount,
          ifAbsent: () => tx.amount);
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'transactionsFab',
        onPressed: _openSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movimentações',
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Organize entradas, saídas e pagamentos em tempo real.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todas',
                    selected: _filter == null,
                    onTap: () => _applyFilter(null),
                    icon: Icons.all_inclusive_rounded,
                  ),
                  _FilterChip(
                    label: 'Receitas',
                    selected: _filter == 'INCOME',
                    onTap: () => _applyFilter('INCOME'),
                    icon: Icons.arrow_upward_rounded,
                  ),
                  _FilterChip(
                    label: 'Despesas',
                    selected: _filter == 'EXPENSE',
                    onTap: () => _applyFilter('EXPENSE'),
                    icon: Icons.arrow_downward_rounded,
                  ),
                  _FilterChip(
                    label: 'Pagamentos',
                    selected: _filter == 'DEBT_PAYMENT',
                    onTap: () => _applyFilter('DEBT_PAYMENT'),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: FutureBuilder<List<TransactionModel>>(
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
                            'Não conseguimos carregar as transações agora.',
                            style: textTheme.titleMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _refresh,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      );
                    }

                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          _EmptyState(
                              message:
                                  'Cadastre sua primeira transação para acompanhar seu fluxo.'),
                        ],
                      );
                    }

                    final totals = _buildTotals(transactions);

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      itemCount: transactions.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _TransactionsSummaryStrip(
                            currency: _currency,
                            totals: totals,
                            activeFilter: _filter,
                          );
                        }
                        final transaction = transactions[index - 1];
                        return _TransactionTile(
                          transaction: transaction,
                          currency: _currency,
                          onRemove: () => _deleteTransaction(transaction),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = selected ? Colors.white : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.currency,
    required this.onRemove,
  });

  final TransactionModel transaction;
  final NumberFormat currency;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final accent = _colorFor(transaction.type);
    final icon = _iconFor(transaction.type);
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      color: accent,
      fontWeight: FontWeight.w700,
    );
    final groupLabel = transaction.category?.group != null
        ? CategoryGroupMetadata.labels[transaction.category!.group!] ??
            transaction.category!.group!
        : null;
    final recurrenceLabel = transaction.recurrenceLabel;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: tokens.cardRadius,
          border: Border.all(color: theme.dividerColor),
          boxShadow: tokens.mediumShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: tokens.tileRadius,
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    transaction.category?.name ?? 'Sem categoria',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (groupLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      groupLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (transaction.isRecurring && recurrenceLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _RecurringBadge(
                        primary: recurrenceLabel,
                        endDate: transaction.recurrenceEndDate,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currency.format(transaction.amount), style: amountStyle),
                const SizedBox(height: 6),
                Text(
                  DateFormat('dd/MM').format(transaction.date),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Excluir transação',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorFor(String type) {
    switch (type) {
      case 'INCOME':
        return AppColors.support;
      case 'EXPENSE':
        return AppColors.alert;
      case 'DEBT_PAYMENT':
        return AppColors.highlight;
      default:
        return AppColors.primary;
    }
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'INCOME':
        return Icons.arrow_upward_rounded;
      case 'EXPENSE':
        return Icons.arrow_downward_rounded;
      case 'DEBT_PAYMENT':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.swap_horiz_rounded;
    }
  }
}

class _TransactionsSummaryStrip extends StatelessWidget {
  const _TransactionsSummaryStrip({
    required this.currency,
    required this.totals,
    required this.activeFilter,
  });

  final NumberFormat currency;
  final Map<String, double> totals;
  final String? activeFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    final metrics = [
      _SummaryMetric(
        key: 'INCOME',
        title: 'Receitas',
        value: totals['INCOME'] ?? 0,
        icon: Icons.arrow_upward_rounded,
        color: AppColors.support,
      ),
      _SummaryMetric(
        key: 'EXPENSE',
        title: 'Despesas',
        value: totals['EXPENSE'] ?? 0,
        icon: Icons.arrow_downward_rounded,
        color: AppColors.alert,
      ),
      _SummaryMetric(
        key: 'DEBT_PAYMENT',
        title: 'Pagamentos de dívida',
        value: totals['DEBT_PAYMENT'] ?? 0,
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.highlight,
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < metrics.length; i++) {
      final metric = metrics[i];
      final dimmed = activeFilter != null && activeFilter != metric.key;
      children.add(
        Expanded(
          child: _SummaryMetricCard(
            metric: metric,
            currency: currency,
            dimmed: dimmed,
          ),
        ),
      );
      if (i != metrics.length - 1) {
        children.add(const SizedBox(width: 12));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: tokens.cardRadius,
        border: Border.all(color: theme.dividerColor),
        boxShadow: tokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo rápido',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(children: children),
        ],
      ),
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric({
    required this.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String key;
  final String title;
  final double value;
  final IconData icon;
  final Color color;
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.metric,
    required this.currency,
    required this.dimmed,
  });

  final _SummaryMetric metric;
  final NumberFormat currency;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: dimmed ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: metric.color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: metric.color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, color: metric.color, size: 20),
            const SizedBox(height: 14),
            Text(
              metric.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              currency.format(metric.value),
              style: theme.textTheme.titleMedium?.copyWith(
                color: metric.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringBadge extends StatelessWidget {
  const _RecurringBadge({
    required this.primary,
    this.endDate,
  });

  final String primary;
  final DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = endDate != null
        ? 'Até ${DateFormat('dd/MM/yyyy', 'pt_BR').format(endDate!)}'
        : 'Sem data final definida';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.repeat_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
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
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
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
