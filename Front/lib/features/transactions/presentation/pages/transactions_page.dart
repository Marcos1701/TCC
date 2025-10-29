import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
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
                  ),
                  _FilterChip(
                    label: 'Receitas',
                    selected: _filter == 'INCOME',
                    onTap: () => _applyFilter('INCOME'),
                  ),
                  _FilterChip(
                    label: 'Despesas',
                    selected: _filter == 'EXPENSE',
                    onTap: () => _applyFilter('EXPENSE'),
                  ),
                  _FilterChip(
                    label: 'Dívidas',
                    selected: _filter == 'DEBT_PAYMENT',
                    onTap: () => _applyFilter('DEBT_PAYMENT'),
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

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ChoiceChip(
        label: Text(label),
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
