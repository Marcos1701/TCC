import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/models/transaction_link.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/transactions_viewmodel.dart';
import '../widgets/payment_wizard.dart';
import '../widgets/transaction_details_sheet.dart';
import '../widgets/transaction_filter_chip.dart';
import '../widgets/transaction_link_details_sheet.dart';
import '../widgets/transaction_link_tile.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transaction_wizard.dart';
import '../widgets/transactions_empty_state.dart';
import '../widgets/transactions_summary_strip.dart';


class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage>
    with AutomaticKeepAliveClientMixin {
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _cacheManager = CacheManager();
  late final TransactionsViewModel _viewModel;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _viewModel = TransactionsViewModel();
    _viewModel.loadTransactions();
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    _viewModel.dispose();
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.transactions)) {
      _viewModel.refreshSilently();
      _cacheManager.clearInvalidation(CacheType.transactions);
    }
  }

  Future<void> _openSheet() async {
    final created = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TransactionWizard(),
    );

    if (created == null) return;
    
    _cacheManager.invalidateAfterTransaction(action: 'transaction created');
    
    if (!mounted) return;
    
    FeedbackService.showTransactionCreated(
      context,
      amount: created['amount'] ?? 0.0,
      type: created['type'] ?? 'EXPENSE',
      xpEarned: created['xp_earned'] as int?,
    );
  }

  Future<void> _openPaymentWizard() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const PaymentWizard(),
    );

    if (result == true) {
      _viewModel.refreshSilently();
    }
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirm = await FeedbackService.showConfirmationDialog(
      context: context,
      title: 'Confirmar exclusão',
      message: 'Confirmar exclusão de "${transaction.description}"?',
      confirmText: 'Excluir',
      isDangerous: true,
    );

    if (!confirm) return;

    try {
      final deleted = await _viewModel.deleteTransaction(transaction);
      
      if (!mounted) return;
      
      if (deleted) {
        FeedbackService.showSuccess(
          context,
          'Transação removida com sucesso.',
        );
      } else {
        FeedbackService.showError(
          context,
          'Transação não encontrada.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Não foi possível remover a transação.';
      if (e is Failure) {
        errorMessage = e.message;
      }
      
      FeedbackService.showError(
        context,
        errorMessage,
      );
    }
  }

  void _applyFilter(String? type) {
    setState(() {
      _viewModel.updateFilter(type);
    });
  }

  void _applyScheduleFilter(String? status) {
    setState(() {
      _viewModel.updateScheduleFilter(status);
    });
  }

  Map<String, double> _buildTotals(List<TransactionModel> transactions) {
    final totals = <String, double>{
      'INCOME': 0,
      'EXPENSE': 0,
    };
    
    for (final tx in transactions) {
      totals.update(tx.type, (value) => value + tx.amount,
          ifAbsent: () => tx.amount);
    }
    
    return totals;
  }

  /// Returns a human-readable date label for grouping
  String _getDateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(itemDate).inDays;
    
    // Future dates (scheduled transactions)
    if (diff < 0) {
      final futureDiff = -diff;
      if (futureDiff == 1) return 'Amanhã';
      if (futureDiff < 7) return 'Próxima Semana';
      if (futureDiff < 30) return 'Próximo Mês';
      return 'Agendado';
    }
    
    // Past and present dates
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    if (diff < 7) return 'Esta Semana';
    if (diff < 30) return 'Este Mês';
    if (diff < 365) return DateFormat('MMMM yyyy', 'pt_BR').format(date);
    return DateFormat('yyyy', 'pt_BR').format(date);
  }

  /// Groups items and inserts date headers
  List<Map<String, dynamic>> _groupItemsByDate(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return items;
    
    final result = <Map<String, dynamic>>[];
    String? currentGroup;
    
    for (final item in items) {
      final date = item['date'] as DateTime;
      final group = _getDateGroupLabel(date);
      
      if (group != currentGroup) {
        result.add({
          'type': 'header',
          'data': group,
          'date': date,
        });
        currentGroup = group;
      }
      result.add(item);
    }
    
    return result;
  }

  void _showLinkDetails(TransactionLinkModel link) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => TransactionLinkDetailsSheet(
        link: link,
        currency: _currency,
        onDelete: () async {
          await _viewModel.repository.deleteTransactionLink(link.identifier);
          
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
          
          _viewModel.refreshSilently();
          
          if (mounted && context.mounted) {
            FeedbackService.showSuccess(
              context,
              'Vinculo removido com sucesso.',
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
        automaticallyImplyLeading: true,
        actions: [

          IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            tooltip: 'Novo Pagamento',
            onPressed: _openPaymentWizard,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _viewModel.loadTransactions(type: _viewModel.filter),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Filtros:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TransactionFilterChip(
                            label: 'Todas',
                            selected: _viewModel.filter == null,
                            onTap: () => _applyFilter(null),
                            icon: Icons.all_inclusive_rounded,
                          ),
                          TransactionFilterChip(
                            label: 'Receitas',
                            selected: _viewModel.filter == 'INCOME',
                            onTap: () => _applyFilter('INCOME'),
                            icon: Icons.arrow_upward_rounded,
                          ),
                          TransactionFilterChip(
                            label: 'Despesas',
                            selected: _viewModel.filter == 'EXPENSE',
                            onTap: () => _applyFilter('EXPENSE'),
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TransactionFilterChip(
                            label: 'Todas',
                            selected: _viewModel.scheduleFilter == null,
                            onTap: () => _applyScheduleFilter(null),
                            icon: Icons.all_inclusive_rounded,
                          ),
                          TransactionFilterChip(
                            label: 'Efetivadas',
                            selected: _viewModel.scheduleFilter == 'effective',
                            onTap: () => _applyScheduleFilter('effective'),
                            icon: Icons.check_circle_outline_rounded,
                          ),
                          TransactionFilterChip(
                            label: 'Agendadas',
                            selected: _viewModel.scheduleFilter == 'scheduled',
                            onTap: () => _applyScheduleFilter('scheduled'),
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                onChanged: (query) => _viewModel.updateSearchQuery(query),
                decoration: InputDecoration(
                  hintText: 'Buscar por descrição ou categoria...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => _viewModel.loadTransactions(type: _viewModel.filter),
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) {
                    if (_viewModel.isLoading && _viewModel.transactions.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_viewModel.hasError) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                            'Não foi possível carregar as transações.',
                            style: textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          if (_viewModel.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _viewModel.errorMessage!,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => _viewModel.loadTransactions(type: _viewModel.filter),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      );
                    }

                    final transactions = _viewModel.transactions;
                    final links = _viewModel.links;
                    
                    if (transactions.isEmpty && links.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          TransactionsEmptyState(
                            message:
                                'Nenhuma transação encontrada.\nCadastre sua primeira transação para começar!',
                          ),
                        ],
                      );
                    }

                    final totals = _buildTotals(transactions);
                    
                    final allItems = <Map<String, dynamic>>[];
                    
                    for (final transaction in transactions) {
                      allItems.add({
                        'type': 'transaction',
                        'data': transaction,
                        'date': transaction.date,
                      });
                    }
                    
                    for (final link in links) {
                      allItems.add({
                        'type': 'link',
                        'data': link,
                        'date': link.createdAt,
                      });
                    }
                    
                    allItems.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
                    
                    // Group items by date with headers
                    final groupedItems = _groupItemsByDate(allItems);

                    return Stack(
                      children: [
                        ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                          itemCount: groupedItems.length + 1,
                          separatorBuilder: (_, index) {
                            if (index == 0) {
                              return const SizedBox(height: 20);
                            }
                            // Check if next item is a header - add more space before headers
                            if (index < groupedItems.length) {
                              final nextItem = groupedItems[index];
                              if (nextItem['type'] == 'header') {
                                return const SizedBox(height: 16);
                              }
                            }
                            return const SizedBox(height: 8);
                          },
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return TransactionsSummaryStrip(
                                currency: _currency,
                                totals: totals,
                                activeFilter: _viewModel.filter,
                              );
                            }
                            
                            final item = groupedItems[index - 1];
                            final itemType = item['type'] as String;
                            
                            // Render date group header
                            if (itemType == 'header') {
                              final label = item['data'] as String;
                              return DateGroupHeader(label: label);
                            }
                            
                            if (itemType == 'transaction') {
                              final transaction = item['data'] as TransactionModel;
                              return TransactionTile(
                                transaction: transaction,
                                currency: _currency,
                                onTap: () async {
                                  final updated = await showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (context) => TransactionDetailsSheet(
                                      transaction: transaction,
                                      repository: _viewModel.repository,
                                      onUpdate: () => _viewModel.refreshSilently(),
                                    ),
                                  );
                                  if (updated == true) {
                                    _viewModel.refreshSilently();
                                  }
                                },
                                onRemove: () => _deleteTransaction(transaction),
                              );
                            } else {
                              final link = item['data'] as TransactionLinkModel;
                              return TransactionLinkTile(
                                link: link,
                                currency: _currency,
                                onTap: () {
                                  _showLinkDetails(link);
                                },
                              );
                            }
                          },
                        ),
                        if (_viewModel.isLoading && _viewModel.transactions.isNotEmpty)
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Atualizando...',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
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

/// Date group header widget for transaction list sections
class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.primary.withOpacity(0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

