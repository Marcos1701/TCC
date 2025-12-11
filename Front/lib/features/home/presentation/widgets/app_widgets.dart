import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/models/transaction_link.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/repositories/transaction_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';

class MonthSummaryCard extends StatelessWidget {
  const MonthSummaryCard({
    super.key,
    required this.summary,
    required this.currency,
  });

  final SummaryMetrics summary;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    // Cores baseadas nos ranges saudáveis
    final tpsColor = summary.tps >= 20
        ? Colors.green
        : (summary.tps >= 10 ? Colors.amber : Colors.red);
    final rdrColor = summary.rdr <= 30
        ? Colors.green
        : (summary.rdr <= 50 ? Colors.amber : Colors.red);
    final iliColor = summary.ili >= 6
        ? Colors.green
        : (summary.ili >= 3 ? Colors.blue : Colors.amber);

    return Card(
      color: Colors.grey[900],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Indicadores Financeiros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Mês Atual',
                    style: TextStyle(color: Colors.purpleAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _IndicatorItem(
                    label: 'TPS (Poupança)',
                    value: '${summary.tps.toStringAsFixed(1)}%',
                    color: tpsColor,
                    icon: Icons.savings,
                    dialogTitle: UxStrings.tpsTitle,
                    dialogCalculation: UxStrings.tpsCalculation,
                    dialogDescription: UxStrings.tpsDescription,
                  ),
                ),
                Expanded(
                  child: _IndicatorItem(
                    label: 'RDR (Dívidas)',
                    value: '${summary.rdr.toStringAsFixed(1)}%',
                    color: rdrColor,
                    icon: Icons.money_off,
                    dialogTitle: UxStrings.rdrTitle,
                    dialogCalculation: UxStrings.rdrCalculation,
                    dialogDescription: UxStrings.rdrDescription,
                  ),
                ),
                Expanded(
                  child: _IndicatorItem(
                    label: 'ILI (Reserva)',
                    value: '${summary.ili.toStringAsFixed(1)}x',
                    color: iliColor,
                    icon: Icons.account_balance,
                    dialogTitle: UxStrings.iliTitle,
                    dialogCalculation: UxStrings.iliCalculation,
                    dialogDescription: UxStrings.iliDescription,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receitas',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(summary.totalIncome),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Despesas',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(summary.totalExpense),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aportes',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(summary.totalAportes),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Saldo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(summary.totalIncome - summary.totalExpense),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: (summary.totalIncome - summary.totalExpense) >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorItem extends StatelessWidget {
  const _IndicatorItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.dialogTitle,
    required this.dialogCalculation,
    required this.dialogDescription,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String dialogTitle;
  final String dialogCalculation;
  final String dialogDescription;

  void _showExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dialogTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FÓRMULA',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dialogCalculation,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontFamily: 'Courier',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              dialogDescription,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
                fontSize: 14,
              ),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showExplanation(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[600],
                    size: 12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SummaryMetric extends StatelessWidget {
  const SummaryMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.currency,
  });

  final String label;
  final double value;
  final Color color;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currency.format(value),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class WeeklyChallengeCard extends StatelessWidget {
  const WeeklyChallengeCard({
    super.key,
    required this.mission,
    required this.onTap,
  });

  final MissionProgressModel mission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = mission.progress / 100.0;
    final isPending = mission.status == 'PENDING';
    final isCompleted = mission.progress >= 100;
    final challengeTitle = isPending ? 'Desafio Sugerido' : 'Desafio em Andamento';

    // Define colors and labels based on status
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (isCompleted) {
      statusColor = Colors.green;
      statusLabel = 'Concluído';
      statusIcon = Icons.check_circle;
    } else if (isPending) {
      statusColor = Colors.amber;
      statusLabel = 'Sugestão';
      statusIcon = Icons.lightbulb_outline;
    } else {
      statusColor = AppColors.primary;
      statusLabel = 'Em andamento';
      statusIcon = Icons.play_circle_fill;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: isPending ? Colors.amber[900] : Colors.purple[900],
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      challengeTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mission.mission.title,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation(
                    isCompleted ? Colors.green : Colors.amber,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app,
                              color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Toque para aceitar',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '${mission.progress.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${mission.mission.rewardPoints} ${UxStrings.points}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({
    super.key,
    required this.onAddTransaction,
    required this.onViewAnalysis,
  });

  final VoidCallback onAddTransaction;
  final VoidCallback onViewAnalysis;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ações Rápidas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                QuickActionButton(
                  icon: Icons.add_circle,
                  label: 'Adicionar',
                  color: Colors.green,
                  onTap: onAddTransaction,
                ),
                QuickActionButton(
                  icon: Icons.analytics,
                  label: 'Análise',
                  color: Colors.purple,
                  onTap: onViewAnalysis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentTransactionsSection extends StatefulWidget {
  const RecentTransactionsSection({
    super.key,
    required this.repository,
    required this.currency,
    required this.onViewAll,
  });

  final FinanceRepository repository;
  final NumberFormat currency;
  final VoidCallback onViewAll;

  @override
  State<RecentTransactionsSection> createState() =>
      _RecentTransactionsSectionState();
}

class _RecentTransactionsSectionState extends State<RecentTransactionsSection> {
  List<TransactionModel>? _transactions;
  bool _isLoading = true;
  final _cacheManager = CacheManager();

  @override
  void initState() {
    super.initState();
    _cacheManager.addListener(_onCacheInvalidated);
    _loadTransactions();
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.transactions) ||
        _cacheManager.isInvalidated(CacheType.dashboard)) {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    if (kDebugMode) {
      debugPrint('📥 RecentTransactionsSection: Carregando transações...');
    }
    try {
      final allTransactions = await widget.repository.fetchTransactions();
      if (kDebugMode) {
        debugPrint(
            '✅ RecentTransactionsSection: ${allTransactions.length} transações recebidas');
      }
      if (mounted) {
        setState(() {
          _transactions = allTransactions.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ RecentTransactionsSection: Erro ao carregar: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showTransactionDetails(
      BuildContext context, TransactionModel transaction) {
    final transactionRepository = TransactionRepository();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TransactionDetailsSheet(
        transaction: transaction,
        repository: transactionRepository,
        onUpdate: () {
          _loadTransactions();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transações Recentes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: widget.onViewAll,
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_transactions == null || _transactions!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Nenhuma transação ainda',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              )
            else
              ..._transactions!.map((transaction) => SimpleTransactionTile(
                    transaction: transaction,
                    currency: widget.currency,
                    onTap: () => _showTransactionDetails(context, transaction),
                  )),
          ],
        ),
      ),
    );
  }
}

class SimpleTransactionTile extends StatelessWidget {
  const SimpleTransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    this.onTap,
  });

  final TransactionModel transaction;
  final NumberFormat currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'INCOME';
    final isAporte = TransactionTileHelper.isAporte(transaction);
    final color = TransactionTileHelper.colorFor(transaction.type, isAporte: isAporte);
    final icon = TransactionTileHelper.iconFor(transaction.type, isAporte: isAporte);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(transaction.date),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        if (transaction.category != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              transaction.category!.name,
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                currency.format(transaction.amount),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentPaymentsCard extends StatefulWidget {
  const RecentPaymentsCard({
    super.key,
    required this.repository,
    required this.currency,
    required this.onCreatePayment,
    required this.onViewAll,
  });

  final FinanceRepository repository;
  final NumberFormat currency;
  final VoidCallback onCreatePayment;
  final VoidCallback onViewAll;

  @override
  State<RecentPaymentsCard> createState() => _RecentPaymentsCardState();
}

class _RecentPaymentsCardState extends State<RecentPaymentsCard> {
  List<TransactionLinkModel>? _payments;
  bool _isLoading = true;
  final _cacheManager = CacheManager();

  @override
  void initState() {
    super.initState();
    _cacheManager.addListener(_onCacheInvalidated);
    _loadPayments();
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.transactions) ||
        _cacheManager.isInvalidated(CacheType.dashboard)) {
      _loadPayments();
    }
  }

  Future<void> _loadPayments() async {
    try {
      final allPayments = await widget.repository.fetchTransactionLinks();
      if (mounted) {
        setState(() {
          _payments = allPayments.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Pagamentos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: widget.onViewAll,
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_payments == null || _payments!.isEmpty)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 48,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum pagamento ainda',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crie seu primeiro pagamento',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onCreatePayment,
                      icon: const Icon(Icons.add),
                      label: const Text('Novo Pagamento'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  ..._payments!.map((payment) => SimplePaymentTile(
                        payment: payment,
                        currency: widget.currency,
                      )),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onCreatePayment,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo Pagamento'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class SimplePaymentTile extends StatelessWidget {
  const SimplePaymentTile({
    super.key,
    required this.payment,
    required this.currency,
  });

  final TransactionLinkModel payment;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.link,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payment.linkTypeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                currency.format(payment.linkedAmount),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (payment.sourceTransaction != null &&
              payment.targetTransaction != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    payment.sourceTransaction!.description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    payment.targetTransaction!.description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            DateFormat('dd/MM/yyyy • HH:mm').format(payment.createdAt),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
