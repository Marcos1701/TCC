import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFormatter = DateFormat('dd MMM yyyy', 'pt_BR');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico de transações',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Cadastre receitas e despesas para que o GenApp calcule automaticamente '
            'os indicadores TPS e RDR.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _mockTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final transaction = _mockTransactions[index];
                final isIncome = transaction.type == _TransactionType.income;
                final amountPrefix = isIncome ? '+' : '-';
                final amountColor =
                    isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
                final formattedAmount =
                    currencyFormatter.format(transaction.amount.abs());
                final formattedDate = dateFormatter.format(transaction.date);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(transaction.description),
                    subtitle: Text(transaction.category),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$amountPrefix $formattedAmount',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: amountColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Registrar transação'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}

enum _TransactionType { income, expense }

class _TransactionItem {
  const _TransactionItem({
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    required this.type,
  });

  final String description;
  final String category;
  final double amount;
  final DateTime date;
  final _TransactionType type;
}

const _mockTransactions = <_TransactionItem>[
  _TransactionItem(
    description: 'Salário',
    category: 'Receita Fixa',
    amount: 4200,
    date: DateTime(2025, 1, 5),
    type: _TransactionType.income,
  ),
  _TransactionItem(
    description: 'Cartão de crédito',
    category: 'Dívidas',
    amount: 650,
    date: DateTime(2025, 1, 12),
    type: _TransactionType.expense,
  ),
  _TransactionItem(
    description: 'Alimentação',
    category: 'Despesas Variáveis',
    amount: 320,
    date: DateTime(2025, 1, 14),
    type: _TransactionType.expense,
  ),
  _TransactionItem(
    description: 'Freelance',
    category: 'Receita Variável',
    amount: 850,
    date: DateTime(2025, 1, 18),
    type: _TransactionType.income,
  ),
];
