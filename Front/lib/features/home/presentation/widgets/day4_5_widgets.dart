import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/user_friendly_strings.dart';
import '../../../../core/models/dashboard.dart';
import '../../../../core/models/mission_progress.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';

// ========== DIA 4-5: NOVOS WIDGETS SIMPLIFICADOS ==========

/// Card de resumo mensal simplificado
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
    final income = summary.totalIncome;
    final expense = summary.totalExpense;
    final balance = income - expense;

    return Card(
      color: Colors.grey[900],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este mês',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SummaryMetric(
                    label: '💰 ${UxStrings.income}',
                    value: income,
                    color: Colors.green,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryMetric(
                    label: '💸 ${UxStrings.expense}',
                    value: expense,
                    color: Colors.red,
                    currency: currency,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  UxStrings.balance,
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                Text(
                  currency.format(balance),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? Colors.green : Colors.red,
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

/// Card de desafio da semana em destaque
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: Colors.purple[900],
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Desafio da Semana',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                  valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${mission.progress.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

/// Card de ações rápidas
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({
    super.key,
    required this.onAddTransaction,
    required this.onViewGoals,
    required this.onViewAnalysis,
  });

  final VoidCallback onAddTransaction;
  final VoidCallback onViewGoals;
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
                  icon: Icons.flag,
                  label: 'Metas',
                  color: Colors.blue,
                  onTap: onViewGoals,
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

/// Seção de transações recentes (5 últimas)
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
  State<RecentTransactionsSection> createState() => _RecentTransactionsSectionState();
}

class _RecentTransactionsSectionState extends State<RecentTransactionsSection> {
  List<TransactionModel>? _transactions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final allTransactions = await widget.repository.fetchTransactions();
      if (mounted) {
        setState(() {
          _transactions = allTransactions.take(5).toList();
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
  });

  final TransactionModel transaction;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'INCOME';
    final color = isIncome ? Colors.green : Colors.red;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        transaction.description,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        DateFormat('dd/MM/yyyy').format(transaction.date),
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: Text(
        currency.format(transaction.amount),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
