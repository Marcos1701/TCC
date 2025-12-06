import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';

class PaymentWizard extends StatefulWidget {
  const PaymentWizard({super.key});

  @override
  State<PaymentWizard> createState() => _PaymentWizardState();
}

class _PaymentWizardState extends State<PaymentWizard> {
  final FinanceRepository _repository = FinanceRepository();
  final CacheManager _cacheManager = CacheManager();
  final PageController _pageController = PageController();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  int _currentStep = 0;

  List<TransactionModel> _availableIncomes = [];
  List<TransactionModel> _availableExpenses = [];
  bool _isLoadingData = false;

  final Map<String, double> _selectedIncomes = {};
  final Map<String, double> _selectedExpenses = {};

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoadingData = true);

    try {
      final incomes = await _repository.fetchAvailableIncomes();
      final expenses = await _repository.fetchPendingExpenses();

      if (mounted) {
        setState(() {
          _availableIncomes = incomes;
          _availableExpenses = expenses;
          _isLoadingData = false;
        });
        
        _applySuggestedIncome();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        FeedbackService.showError(
          context,
          'Erro ao carregar transações: $e',
        );
      }
    }
  }

  void _applySuggestedIncome() {
    if (_availableExpenses.length == 1 && _availableIncomes.isNotEmpty) {
      final expense = _availableExpenses.first;
      final neededAmount = expense.availableAmount ?? expense.amount;
      
      final sortedIncomes = _availableIncomes.toList()
        ..sort((a, b) {
          final aAvailable = a.availableAmount ?? a.amount;
          final bAvailable = b.availableAmount ?? b.amount;
          return bAvailable.compareTo(aAvailable);
        });
      
      final bestIncome = sortedIncomes.first;
      final incomeAvailable = bestIncome.availableAmount ?? bestIncome.amount;
      
      if (incomeAvailable >= neededAmount) {
        setState(() {
          _selectedIncomes[bestIncome.id] = neededAmount;
          _selectedExpenses[expense.id] = neededAmount;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 0:
        return _selectedIncomes.isNotEmpty &&
            _selectedIncomes.values.every((v) => v > 0);
      case 1:
        return _selectedExpenses.isNotEmpty &&
            _selectedExpenses.values.every((v) => v > 0);
      case 2:
        return true;
      default:
        return false;
    }
  }

  Future<void> _createTransfers() async {
    if (_isCreating) return;

    final totalIncome =
        _selectedIncomes.values.fold<double>(0, (sum, v) => sum + v);
    final totalExpense =
        _selectedExpenses.values.fold<double>(0, (sum, v) => sum + v);

    if (totalIncome <= 0) {
      FeedbackService.showError(
        context,
        'Selecione pelo menos uma receita com valor maior que zero.',
      );
      return;
    }

    if (totalExpense <= 0) {
      FeedbackService.showError(
        context,
        'Selecione pelo menos uma despesa com valor maior que zero.',
      );
      return;
    }

    if ((totalIncome - totalExpense).abs() > 0.01) {
      final confirm = await FeedbackService.showConfirmationDialog(
        context: context,
        title: 'Valores diferentes',
        message:
            'Total de receitas (${_currency.format(totalIncome)}) é diferente do total de despesas (${_currency.format(totalExpense)}). Deseja continuar?',
        confirmText: 'Continuar',
      );

      if (!confirm) return;
    }

    setState(() => _isCreating = true);

    try {
      final payments = <Map<String, dynamic>>[];

      for (final incomeEntry in _selectedIncomes.entries) {
        final income = _availableIncomes
            .firstWhere((t) => t.id == incomeEntry.key);
        
        for (final expenseEntry in _selectedExpenses.entries) {
          final expense = _availableExpenses
              .firstWhere((t) => t.id == expenseEntry.key);
          
          final proportion = expenseEntry.value / totalExpense;
          final amount = incomeEntry.value * proportion;

          if (amount > 0.01) {
            payments.add({
              'source_id': income.id,
              'target_id': expense.id,
              'amount': amount,
            });
          }
        }
      }

      await _repository.createBulkPayment(
        payments: payments,
        description: 'Pagamento criado via wizard',
      );

      if (!mounted) return;

      _cacheManager.invalidateAfterPayment();

      FeedbackService.showSuccess(
        context,
        '✅ ${payments.length} pagamento(s) criado(s) com sucesso!',
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isCreating = false);

      FeedbackService.showError(
        context,
        'Erro ao criar pagamentos: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(theme),

          _buildProgressIndicator(),

          if (_isLoadingData)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepIncomes(),
                  _buildStepExpenses(),
                  _buildStepReview(),
                ],
              ),
            ),

          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.swap_horiz,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Novo Pagamento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStepTitle(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Passo 1: Selecione as receitas';
      case 1:
        return 'Passo 2: Selecione as despesas';
      case 2:
        return 'Passo 3: Revise e confirme';
      default:
        return '';
    }
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? AppColors.primary
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < 2) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepIncomes() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Selecione as receitas de origem',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha uma ou mais receitas e defina quanto usar de cada uma',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        if (_availableIncomes.isEmpty)
          _buildEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            message: 'Nenhuma receita disponível',
            description: 'Registre receitas primeiro',
          )
        else
          ..._availableIncomes.map((income) {
            final isSelected = _selectedIncomes.containsKey(income.id);
            final selectedAmount = _selectedIncomes[income.id] ?? 0.0;

            return _buildTransactionCard(
              transaction: income,
              isSelected: isSelected,
              selectedAmount: selectedAmount,
              onToggle: () {
                setState(() {
                  if (isSelected) {
                    _selectedIncomes.remove(income.id);
                  } else {
                    _selectedIncomes[income.id] =
                        income.availableAmount ?? income.amount;
                  }
                });
              },
              onAmountChanged: (value) {
                setState(() {
                  _selectedIncomes[income.id] = value;
                });
              },
              maxAmount: income.availableAmount ?? income.amount,
            );
          }),
      ],
    );
  }

  Widget _buildStepExpenses() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Selecione as despesas de destino',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha uma ou mais despesas e defina quanto alocar para cada uma',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        if (_availableExpenses.isEmpty)
          _buildEmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'Nenhuma despesa pendente',
            description: 'Registre despesas primeiro',
          )
        else
          ..._availableExpenses.map((expense) {
            final isSelected = _selectedExpenses.containsKey(expense.id);
            final selectedAmount = _selectedExpenses[expense.id] ?? 0.0;

            return _buildTransactionCard(
              transaction: expense,
              isSelected: isSelected,
              selectedAmount: selectedAmount,
              onToggle: () {
                setState(() {
                  if (isSelected) {
                    _selectedExpenses.remove(expense.id);
                  } else {
                    _selectedExpenses[expense.id] =
                        expense.availableAmount ?? expense.amount;
                  }
                });
              },
              onAmountChanged: (value) {
                setState(() {
                  _selectedExpenses[expense.id] = value;
                });
              },
              maxAmount: expense.availableAmount ?? expense.amount,
            );
          }),
      ],
    );
  }

  Widget _buildStepReview() {
    final totalIncome =
        _selectedIncomes.values.fold<double>(0, (sum, v) => sum + v);
    final totalExpense =
        _selectedExpenses.values.fold<double>(0, (sum, v) => sum + v);
    final difference = totalIncome - totalExpense;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Revise seu pagamento',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Confira os detalhes antes de confirmar',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        _buildReviewSection(
          title: 'Receitas Selecionadas',
          icon: Icons.arrow_upward,
          iconColor: AppColors.support,
          items: _selectedIncomes.entries.map((entry) {
            final income = _availableIncomes.firstWhere((t) => t.id == entry.key);
            return _ReviewItem(
              description: income.description,
              amount: entry.value,
            );
          }).toList(),
          total: totalIncome,
        ),

        const SizedBox(height: 20),

        _buildReviewSection(
          title: 'Despesas Selecionadas',
          icon: Icons.arrow_downward,
          iconColor: AppColors.alert,
          items: _selectedExpenses.entries.map((entry) {
            final expense =
                _availableExpenses.firstWhere((t) => t.id == entry.key);
            return _ReviewItem(
              description: expense.description,
              amount: entry.value,
            );
          }).toList(),
          total: totalExpense,
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: difference.abs() < 0.01
                ? AppColors.support.withOpacity(0.1)
                : AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: difference.abs() < 0.01
                  ? AppColors.support.withOpacity(0.3)
                  : AppColors.warning.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                difference.abs() < 0.01 ? Icons.check_circle : Icons.info,
                color: difference.abs() < 0.01
                    ? AppColors.support
                    : AppColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difference.abs() < 0.01
                          ? 'Valores balanceados'
                          : 'Diferença de valores',
                      style: TextStyle(
                        color: difference.abs() < 0.01
                            ? AppColors.support
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (difference.abs() >= 0.01) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Diferença: ${_currency.format(difference.abs())}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_ReviewItem> items,
    required double total,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _currency.format(item.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(color: Colors.white24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _currency.format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard({
    required TransactionModel transaction,
    required bool isSelected,
    required double selectedAmount,
    required VoidCallback onToggle,
    required Function(double) onAmountChanged,
    required double maxAmount,
  }) {
    return Card(
      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggle(),
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Disponível: ${_currency.format(maxAmount)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(maxDigits: 12),
                        ],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Valor a usar',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixText: 'R\$ ',
                          prefixStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        controller: TextEditingController(
                          text: selectedAmount > 0
                              ? CurrencyInputFormatter.format(selectedAmount)
                              : '',
                        )..selection = TextSelection.fromPosition(
                            TextPosition(
                              offset: selectedAmount > 0
                                  ? CurrencyInputFormatter.format(
                                          selectedAmount)
                                      .length
                                  : 0,
                            ),
                          ),
                        onChanged: (value) {
                          final parsed =
                              CurrencyInputFormatter.parse(value);
                          if (parsed >= 0 && parsed <= maxAmount) {
                            onAmountChanged(parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => onAmountChanged(maxAmount),
                      child: const Text('Máximo'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final canProceed = _canProceedFromStep(_currentStep);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canProceed
                  ? (_currentStep == 2 ? _createTransfers : _nextStep)
                  : null,
              icon: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(_currentStep == 2 ? Icons.check : Icons.arrow_forward),
              label: Text(_currentStep == 2 ? 'Criar Pagamentos' : 'Próximo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem {
  const _ReviewItem({
    required this.description,
    required this.amount,
  });

  final String description;
  final double amount;
}
