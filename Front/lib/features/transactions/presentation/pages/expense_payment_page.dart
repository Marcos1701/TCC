import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/models/transaction_link.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';

class ExpensePaymentPage extends StatefulWidget {
  const ExpensePaymentPage({super.key});

  @override
  State<ExpensePaymentPage> createState() => _ExpensePaymentPageState();
}

class _ExpensePaymentPageState extends State<ExpensePaymentPage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _cacheManager = CacheManager();
  final _amountController = TextEditingController();
  
  List<TransactionModel> _availableIncomes = [];
  List<TransactionModel> _pendingExpenses = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  TransactionModel? _selectedIncome;
  TransactionModel? _selectedExpense;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final incomes = await _repository.fetchAvailableIncomes();
      final expenses = await _repository.fetchPendingExpenses();

      if (!mounted) return;
      setState(() {
        _availableIncomes = incomes;
        _pendingExpenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao carregar dados: $e';
        _isLoading = false;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _createLink(double amount) async {
    if (_selectedIncome == null || _selectedExpense == null) return;

    try {
      final request = CreateTransactionLinkRequest(
        sourceId: _selectedIncome!.id,
        targetId: _selectedExpense!.id,
        amount: amount,
        linkType: 'DEBT_PAYMENT',
      );

      await _repository.createTransactionLink(request);

      if (!mounted) return;
      
      // Invalida cache após pagar despesa
      _cacheManager.invalidateAfterPayment();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vinculação criada com sucesso! ✅'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar vinculação: $e'),
          backgroundColor: AppColors.alert,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagar Despesa'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      backgroundColor: const Color(0xFF121212),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _availableIncomes.isEmpty || _pendingExpenses.isEmpty
                  ? _buildEmpty()
                  : _buildStepper(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.alert),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Erro desconhecido',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              _availableIncomes.isEmpty
                  ? 'Nenhuma receita disponível'
                  : 'Nenhuma despesa pendente',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cadastre transações primeiro',
              style: TextStyle(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Column(
      children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E1E1E),
          child: Row(
            children: [
              _buildStepIndicator(0, 'Receita'),
              Expanded(child: _buildStepLine(0 < _currentStep)),
              _buildStepIndicator(1, 'Despesa'),
              Expanded(child: _buildStepLine(1 < _currentStep)),
              _buildStepIndicator(2, 'Valor'),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: IndexedStack(
            index: _currentStep,
            children: [
              _buildIncomeSelection(),
              _buildDebtSelection(),
              _buildAmountInput(),
            ],
          ),
        ),
        
        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E1E1E),
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
                    ),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 16),
              if (_currentStep < 2)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canProceed() ? _nextStep : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Próximo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.white12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppColors.success
                : isActive
                    ? AppColors.primary
                    : Colors.white12,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isCompleted ? AppColors.success : Colors.white12,
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedIncome != null;
      case 1:
        return _selectedExpense != null;
      case 2:
        return true;
      default:
        return false;
    }
  }

  Widget _buildIncomeSelection() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableIncomes.length,
      itemBuilder: (context, index) {
        final income = _availableIncomes[index];
        final isSelected = _selectedIncome?.id == income.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected ? AppColors.primary.withOpacity(0.2) : const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedIncome = income),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.success),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          income.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          income.category?.name ?? 'Sem categoria',
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Total: ${_currency.format(income.amount)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Disponível: ${_currency.format(income.availableAmount ?? income.amount)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebtSelection() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingExpenses.length,
      itemBuilder: (context, index) {
        final debt = _pendingExpenses[index];
        final isSelected = _selectedExpense?.id == debt.id;
        final percentage = debt.linkPercentage ?? 0.0;
        final remaining = debt.availableAmount ?? debt.amount;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected ? AppColors.primary.withOpacity(0.2) : const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedExpense = debt),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.alert.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.credit_card, color: AppColors.alert),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              debt.description,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              debt.category?.name ?? 'Despesa',
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Total: ${_currency.format(debt.amount)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.alert.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Falta: ${_currency.format(remaining)}',
                            style: const TextStyle(
                              color: AppColors.alert,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 100 ? AppColors.success : AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.toStringAsFixed(1)}% pago',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountInput() {
    final income = _selectedIncome;
    final debt = _selectedExpense;

    if (income == null || debt == null) {
      return const Center(
        child: Text('Selecione uma receita e uma despesa', style: TextStyle(color: Colors.white70)),
      );
    }

    final availableIncome = income.availableAmount ?? income.amount;
    final remainingDebt = debt.availableAmount ?? debt.amount;
    final maxAmount = availableIncome < remainingDebt ? availableIncome : remainingDebt;

    // Atualizar texto do controller apenas se diferente
    final formattedMax = CurrencyInputFormatter.format(maxAmount);
    if (_amountController.text.isEmpty || _amountController.text != formattedMax) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _amountController.text = formattedMax;
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            icon: Icons.account_balance_wallet,
            color: AppColors.success,
            title: income.description,
            subtitle: 'Disponível: ${_currency.format(availableIncome)}',
          ),
          const SizedBox(height: 12),
          const Icon(Icons.arrow_downward, color: AppColors.primary, size: 32),
          const SizedBox(height: 12),
          _buildSummaryCard(
            icon: Icons.credit_card,
            color: AppColors.alert,
            title: debt.description,
            subtitle: 'Falta pagar: ${_currency.format(remainingDebt)}',
          ),
          const SizedBox(height: 24),
          const Text(
            'Valor do pagamento',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(maxDigits: 12),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              prefixStyle: const TextStyle(color: Colors.white70, fontSize: 24),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Mostra 'Máximo' apenas se a despesa for maior que a receita disponível
              if (remainingDebt > availableIncome)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _amountController.text = CurrencyInputFormatter.format(availableIncome),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    ),
                    child: Text(
                      'Máximo\n${_currency.format(availableIncome)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              // Mostra 'Quitar' apenas se a despesa for menor ou igual à receita disponível
              if (remainingDebt <= availableIncome)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _amountController.text = CurrencyInputFormatter.format(remainingDebt),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.alert,
                      side: const BorderSide(color: AppColors.alert),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    ),
                    child: Text(
                      'Quitar\n${_currency.format(remainingDebt)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final amount = CurrencyInputFormatter.parse(_amountController.text);
                if (amount > 0 && amount <= maxAmount) {
                  _createLink(amount);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Valor inválido. Máximo: ${_currency.format(maxAmount)}'),
                      backgroundColor: AppColors.alert,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirmar Pagamento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: color, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
