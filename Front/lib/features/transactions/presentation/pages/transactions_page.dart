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
    final created = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RegisterTransactionSheet(repository: _repository),
    );

    if (created == null) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transação adicionada com sucesso.')),
    );
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Excluir transação', style: TextStyle(color: Colors.white)),
        content: Text(
          'Tem certeza que deseja excluir "${transaction.description}"?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _repository.deleteTransaction(transaction.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transação removida.')),
    );
  }

  void _applyFilter(String? type) {
    setState(() {
      _filter = type;
      _future = _repository.fetchTransactions(type: _filter);
    });
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Transações',
          style: textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Acompanhe todas as suas movimentações financeiras em um só lugar.',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                  height: 1.4,
                ),
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
                            'Não foi possível carregar as transações.',
                            style: textTheme.titleMedium
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

                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          _EmptyState(
                            message:
                                'Nenhuma transação encontrada.\nCadastre sua primeira transação para começar!',
                          ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey[800]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : Colors.grey[400],
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
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
    final groupLabel = transaction.category?.group != null
        ? CategoryGroupMetadata.labels[transaction.category!.group!] ??
            transaction.category!.group!
        : null;
    final recurrenceLabel = transaction.recurrenceLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.category?.name ?? 'Sem categoria',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                if (groupLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    groupLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
                if (transaction.isRecurring && recurrenceLabel != null) ...[
                  const SizedBox(height: 6),
                  _RecurringBadge(
                    primary: recurrenceLabel,
                    endDate: transaction.recurrenceEndDate,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(transaction.amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
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
          ),
          IconButton(
            tooltip: 'Excluir',
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline, color: Colors.grey[500]),
            iconSize: 20,
          ),
        ],
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
        title: 'Pagamentos',
        value: totals['DEBT_PAYMENT'] ?? 0,
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.highlight,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do Período',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                Expanded(
                  child: _SummaryMetricCard(
                    metric: metrics[i],
                    currency: currency,
                    dimmed: activeFilter != null && activeFilter != metrics[i].key,
                  ),
                ),
                if (i < metrics.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: metric.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: metric.color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, color: metric.color, size: 20),
            const SizedBox(height: 10),
            Text(
              metric.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currency.format(metric.value),
              style: theme.textTheme.titleSmall?.copyWith(
                color: metric.color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
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
        : 'Sem data final';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_rounded, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              Text(
                secondary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
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
