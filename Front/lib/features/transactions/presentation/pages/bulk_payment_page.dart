import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../widgets/bulk_payment_components.dart';

/// Página de Pagamento em Lote
/// 
/// Permite selecionar múltiplas receitas e despesas para criar
/// várias vinculações de uma vez, simplificando o controle de pagamentos.
class BulkPaymentPage extends StatefulWidget {
  const BulkPaymentPage({super.key});

  @override
  State<BulkPaymentPage> createState() => _BulkPaymentPageState();
}

class _BulkPaymentPageState extends State<BulkPaymentPage> {
  final _repository = FinanceRepository();
  final _cacheManager = CacheManager();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  // Estado de carregamento
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubmitting = false;
  
  // Dados
  List<TransactionModel> _availableIncomes = [];
  List<TransactionModel> _pendingExpenses = [];
  
  // Seleções (Map<transactionId, amount>)
  final Map<String, double> _selectedIncomes = {};
  final Map<String, double> _selectedExpenses = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
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
      
      // Filtrar apenas transações com ID e saldo disponível
      final validIncomes = incomes.where((income) => 
        income.id.isNotEmpty &&
        (income.availableAmount ?? income.amount) > 0
      ).toList();
      
      final validExpenses = expenses.where((expense) => 
        expense.id.isNotEmpty &&
        (expense.availableAmount ?? expense.amount) > 0
      ).toList();
      
      setState(() {
        _availableIncomes = validIncomes;
        _pendingExpenses = validExpenses;
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

  // Calcular totais
  double get _totalIncomeSelected => _selectedIncomes.values.fold(0.0, (a, b) => a + b);
  double get _totalExpensesSelected => _selectedExpenses.values.fold(0.0, (a, b) => a + b);
  double get _balance => _totalIncomeSelected - _totalExpensesSelected;
  
  bool get _canSubmit => 
      _selectedIncomes.isNotEmpty && 
      _selectedExpenses.isNotEmpty && 
      _balance >= 0;

  Future<void> _submitPayments() async {
    if (!_canSubmit) return;

    // Validação adicional antes de enviar
    if (_selectedIncomes.isEmpty) {
      FeedbackService.showError(context, 'Selecione pelo menos uma receita');
      return;
    }

    if (_selectedExpenses.isEmpty) {
      FeedbackService.showError(context, 'Selecione pelo menos uma despesa');
      return;
    }

    if (_balance < 0) {
      FeedbackService.showError(
        context,
        'Saldo insuficiente! Faltam ${_currency.format(_balance.abs())}',
      );
      return;
    }

    // Validar que todos os valores são positivos
    for (final entry in _selectedIncomes.entries) {
      if (entry.value <= 0) {
        FeedbackService.showError(
          context,
          'Valor da receita deve ser maior que zero',
        );
        return;
      }
    }

    for (final entry in _selectedExpenses.entries) {
      if (entry.value <= 0) {
        FeedbackService.showError(
          context,
          'Valor da despesa deve ser maior que zero',
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // Validar limite de pagamentos (máximo 100)
      final totalPayments = _selectedExpenses.length * _selectedIncomes.length;
      if (totalPayments > 100) {
        throw Exception(
          'Muitas combinações de pagamento ($totalPayments). '
          'Reduza a seleção para menos de 100 combinações.',
        );
      }

      // Montar lista de pagamentos
      final payments = <Map<String, dynamic>>[];
      
      // Para cada despesa selecionada, distribuir pagamento das receitas
      for (final expenseEntry in _selectedExpenses.entries) {
        final expenseUuid = expenseEntry.key;
        final expenseAmount = expenseEntry.value;
        
        // Validar UUID não vazio
        if (expenseUuid.isEmpty) {
          throw Exception('UUID de despesa inválido');
        }
        
        // Validar valor positivo
        if (expenseAmount <= 0) {
          throw Exception('Valor de despesa deve ser positivo');
        }
        
        double remainingToAllocate = expenseAmount;
        
        // Distribuir entre as receitas selecionadas
        for (final incomeEntry in _selectedIncomes.entries) {
          if (remainingToAllocate <= 0) break;
          
          final incomeUuid = incomeEntry.key;
          final incomeAvailable = incomeEntry.value;
          
          // Validar UUID não vazio
          if (incomeUuid.isEmpty) {
            throw Exception('UUID de receita inválido');
          }
          
          // Validar valor positivo
          if (incomeAvailable <= 0) continue;
          
          // Validar que não está vinculando transação consigo mesma
          if (incomeUuid == expenseUuid) {
            throw Exception('Não é possível vincular transação consigo mesma');
          }
          
          // Quanto alocar desta receita para esta despesa
          final allocateAmount = remainingToAllocate < incomeAvailable 
              ? remainingToAllocate 
              : incomeAvailable;
          
          if (allocateAmount > 0) {
            payments.add({
              'source_id': incomeUuid,
              'target_id': expenseUuid,
              'amount': allocateAmount,
            });
            
            remainingToAllocate -= allocateAmount;
            // Reduzir disponível para próximas despesas
            _selectedIncomes[incomeUuid] = incomeAvailable - allocateAmount;
          }
        }
      }

      if (payments.isEmpty) {
        throw Exception('Nenhum pagamento a processar');
      }

      // Enviar ao backend
      final now = DateTime.now();
      final description = 'Pagamento em lote - ${DateFormat('dd/MM/yyyy HH:mm').format(now)}';
      
      final result = await _repository.createBulkPayment(
        payments: payments,
        description: description,
      );

      if (!mounted) return;

      // Invalidar cache
      _cacheManager.invalidateAfterPayment();

      // Feedback de sucesso
      final createdCount = result['created_count'] ?? 0;
      final fullyPaidCount = (result['summary']?['fully_paid_expenses'] as List?)?.length ?? 0;
      
      FeedbackService.showSuccess(
        context,
        '$createdCount pagamentos criados.\n${fullyPaidCount > 0 ? "$fullyPaidCount despesa(s) quitada(s)." : ""}',
      );

      // Voltar para tela anterior
      Navigator.of(context).pop(true);

    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isSubmitting = false);
      
      // Melhorar mensagem de erro
      String errorMessage = 'Erro ao processar pagamentos';
      
      if (e.toString().contains('DioException')) {
        if (e.toString().contains('400')) {
          errorMessage = 'Dados inválidos. Verifique os valores selecionados.';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Sessão expirada. Faça login novamente.';
        } else if (e.toString().contains('403')) {
          errorMessage = 'Você não tem permissão para realizar esta operação.';
        } else if (e.toString().contains('500')) {
          errorMessage = 'Erro no servidor. Tente novamente mais tarde.';
        } else if (e.toString().contains('Network')) {
          errorMessage = 'Sem conexão com a internet.';
        }
      } else {
        // Usar mensagem do erro se disponível
        final errorStr = e.toString();
        if (errorStr.contains('Exception:')) {
          errorMessage = errorStr.replaceFirst('Exception:', '').trim();
        } else {
          errorMessage = errorStr;
        }
      }
      
      FeedbackService.showError(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Pagar Despesas',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? _buildErrorState(theme)
              : _buildContent(theme, tokens),
      bottomNavigationBar: !_isLoading && _errorMessage == null
          ? _buildBottomBar(theme, tokens)
          : null,
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.alert),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, AppDecorations tokens) {
    if (_availableIncomes.isEmpty && _pendingExpenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
              const SizedBox(height: 16),
              Text(
                'Nenhuma pendência! 🎉',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Você não tem despesas pendentes ou receitas disponíveis no momento.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instruções
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: tokens.cardRadius,
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Selecione as receitas que deseja usar e as despesas que deseja pagar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Seção de Receitas
          const TransactionSectionHeader(
            icon: Icons.account_balance_wallet,
            title: 'Receitas Disponíveis',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          
          if (_availableIncomes.isEmpty)
            EmptyTransactionCard(
              message: 'Nenhuma receita disponível',
              tokens: tokens,
            )
          else
            ..._availableIncomes.map((income) => _buildIncomeCard(income, tokens)),
          
          const SizedBox(height: 24),
          
          // Seção de Despesas
          const TransactionSectionHeader(
            icon: Icons.receipt_long,
            title: 'Despesas Pendentes',
            color: AppColors.alert,
          ),
          const SizedBox(height: 12),
          
          if (_pendingExpenses.isEmpty)
            EmptyTransactionCard(
              message: 'Nenhuma despesa pendente',
              tokens: tokens,
            )
          else
            ..._pendingExpenses.map((expense) => _buildExpenseCard(expense, tokens)),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(TransactionModel income, AppDecorations tokens) {
    final incomeKey = income.id;
    final isSelected = _selectedIncomes.containsKey(incomeKey);
    final available = income.availableAmount ?? income.amount;
    final selectedAmount = _selectedIncomes[incomeKey] ?? available;
    
    return PaymentTransactionCard(
      transaction: income,
      type: PaymentCardType.income,
      isSelected: isSelected,
      selectedAmount: selectedAmount,
      tokens: tokens,
      onToggle: () {
        setState(() {
          if (isSelected) {
            _selectedIncomes.remove(incomeKey);
          } else {
            _selectedIncomes[incomeKey] = available;
          }
        });
      },
      onAmountChanged: (amount) {
        setState(() {
          if (amount > 0) {
            _selectedIncomes[incomeKey] = amount;
          } else {
            _selectedIncomes.remove(incomeKey);
          }
        });
      },
      onMaxPressed: () => setState(() => _selectedIncomes[incomeKey] = available),
    );
  }

  Widget _buildExpenseCard(TransactionModel expense, AppDecorations tokens) {
    final expenseKey = expense.id;
    final isSelected = _selectedExpenses.containsKey(expenseKey);
    final remaining = expense.availableAmount ?? expense.amount;
    final selectedAmount = _selectedExpenses[expenseKey] ?? remaining;
    
    return PaymentTransactionCard(
      transaction: expense,
      type: PaymentCardType.expense,
      isSelected: isSelected,
      selectedAmount: selectedAmount,
      tokens: tokens,
      onToggle: () {
        setState(() {
          if (isSelected) {
            _selectedExpenses.remove(expenseKey);
          } else {
            _selectedExpenses[expenseKey] = remaining;
          }
        });
      },
      onAmountChanged: (amount) {
        setState(() {
          if (amount > 0) {
            _selectedExpenses[expenseKey] = amount;
          } else {
            _selectedExpenses.remove(expenseKey);
          }
        });
      },
      onMaxPressed: () => setState(() => _selectedExpenses[expenseKey] = remaining),
    );
  }

  Widget _buildBottomBar(ThemeData theme, AppDecorations tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: tokens.sheetRadius.topLeft),
        border: const Border(top: BorderSide(color: Colors.white12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Resumo
            PaymentSummaryRow(
              incomeTotal: _totalIncomeSelected,
              expenseTotal: _totalExpensesSelected,
              balance: _balance,
            ),
            
            const SizedBox(height: 16),
            
            // Botão de confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit && !_isSubmitting ? _submitPayments : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline),
                          const SizedBox(width: 8),
                          Text(
                            'Confirmar Pagamento${_selectedExpenses.length > 1 ? "s" : ""} (${_selectedExpenses.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            // Texto de validação
            if (!_canSubmit && (_selectedIncomes.isNotEmpty || _selectedExpenses.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _balance < 0
                      ? '⚠️ Saldo insuficiente para pagar todas as despesas'
                      : '💡 Selecione pelo menos uma receita e uma despesa',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _balance < 0 ? AppColors.alert : AppColors.highlight,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
