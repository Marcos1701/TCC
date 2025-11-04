import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/models/transaction_link.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/category_groups.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../presentation/widgets/register_transaction_sheet.dart';
import '../../presentation/widgets/transaction_details_sheet.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _cacheManager = CacheManager();
  String? _filter;
  late Future<Map<String, dynamic>> _future = _fetchData();

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
    if (_cacheManager.isInvalidated(CacheType.transactions)) {
      _refresh();
      _cacheManager.clearInvalidation(CacheType.transactions);
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final transactions = await _repository.fetchTransactions(type: _filter);
    final links = await _repository.fetchTransactionLinks();
    return {
      'transactions': transactions,
      'links': links,
    };
  }

  Future<void> _refresh() async {
    final data = await _fetchData();
    if (!mounted) return;
    
    // Atualiza o estado DEPOIS de todo trabalho assíncrono
    if (mounted) {
      setState(() {
        _future = Future.value(data);
      });
    }
  }

  Future<void> _openSheet() async {
    final created = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RegisterTransactionSheet(repository: _repository),
    );

    if (created == null) return;
    
    // Invalida cache após criar transação
    _cacheManager.invalidateAfterTransaction(action: 'transaction created');
    
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
    
    // Invalida cache após deletar transação
    _cacheManager.invalidateAfterTransaction(action: 'transaction deleted');
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transação removida.')),
    );
  }

  void _applyFilter(String? type) {
    setState(() {
      _filter = type;
      _future = _fetchData();
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

  void _showLinkDetails(TransactionLinkModel link) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TransactionLinkDetailsSheet(
        link: link,
        currency: _currency,
        onDelete: () async {
          await _repository.deleteTransactionLink(link.id);
          if (!mounted) return;
          Navigator.pop(context);
          _refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vínculo removido com sucesso.')),
          );
        },
      ),
    );
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
                child: FutureBuilder<Map<String, dynamic>>(
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

                    final data = snapshot.data ?? {};
                    final transactions = (data['transactions'] as List<TransactionModel>?) ?? [];
                    final links = (data['links'] as List<TransactionLinkModel>?) ?? [];
                    
                    if (transactions.isEmpty && links.isEmpty) {
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
                    
                    // Criar lista combinada de transações e links ordenados por data
                    final allItems = <Map<String, dynamic>>[];
                    
                    // Adicionar transações
                    for (final transaction in transactions) {
                      allItems.add({
                        'type': 'transaction',
                        'data': transaction,
                        'date': transaction.date,
                      });
                    }
                    
                    // Adicionar links
                    for (final link in links) {
                      allItems.add({
                        'type': 'link',
                        'data': link,
                        'date': link.createdAt,
                      });
                    }
                    
                    // Ordenar por data (mais recente primeiro)
                    allItems.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      itemCount: allItems.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _TransactionsSummaryStrip(
                            currency: _currency,
                            totals: totals,
                            activeFilter: _filter,
                          );
                        }
                        
                        final item = allItems[index - 1];
                        final itemType = item['type'] as String;
                        
                        if (itemType == 'transaction') {
                          final transaction = item['data'] as TransactionModel;
                          return _TransactionTile(
                            transaction: transaction,
                            currency: _currency,
                            onTap: () async {
                              final updated = await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => TransactionDetailsSheet(
                                  transaction: transaction,
                                  repository: _repository,
                                  onUpdate: _refresh,
                                ),
                              );
                              if (updated == true) {
                                _refresh();
                              }
                            },
                            onRemove: () => _deleteTransaction(transaction),
                          );
                        } else {
                          // É um link de transação
                          final link = item['data'] as TransactionLinkModel;
                          return _TransactionLinkTile(
                            link: link,
                            currency: _currency,
                            onTap: () {
                              // Exibir detalhes do link
                              _showLinkDetails(link);
                            },
                          );
                        }
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
    final accent = _colorFor(transaction.type);
    final icon = _iconFor(transaction.type);
    final groupLabel = transaction.category?.group != null
        ? CategoryGroupMetadata.labels[transaction.category!.group!] ??
            transaction.category!.group!
        : null;
    final recurrenceLabel = transaction.recurrenceLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              color: accent.withValues(alpha: 0.2),
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
          color: metric.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: metric.color.withValues(alpha: 0.3)),
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
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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

class _TransactionLinkTile extends StatelessWidget {
  const _TransactionLinkTile({
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
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
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
                        DateFormat('dd/MM/yyyy • HH:mm').format(link.createdAt),
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
            ),
            if (link.sourceTransaction != null && link.targetTransaction != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 12),
              Row(
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransactionLinkDetailsSheet extends StatelessWidget {
  const _TransactionLinkDetailsSheet({
    required this.link,
    required this.currency,
    required this.onDelete,
  });

  final TransactionLinkModel link;
  final NumberFormat currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
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
                              DateFormat('dd/MM/yyyy • HH:mm').format(link.createdAt),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Valor vinculado',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[400],
                          ),
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
                  ),
                  if (link.sourceTransaction != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Receita utilizada',
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
                              color: AppColors.support.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.trending_up,
                              color: AppColors.support,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  link.sourceTransaction!.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(link.sourceTransaction!.date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            currency.format(link.sourceTransaction!.amount),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.support,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (link.targetTransaction != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Dívida paga',
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
                              color: AppColors.alert.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.trending_down,
                              color: AppColors.alert,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  link.targetTransaction!.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(link.targetTransaction!.date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            currency.format(link.targetTransaction!.amount),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.alert,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (link.description != null && link.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Descrição',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      link.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
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
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
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
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(
                                      'Cancelar',
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
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
                              onDelete();
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.alert,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
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

