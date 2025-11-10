import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/currency_input_formatter.dart';

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
      
      // Filtrar apenas transações com UUID e saldo disponível
      final validIncomes = incomes.where((income) => 
        income.uuid != null && 
        income.uuid!.isNotEmpty &&
        (income.availableAmount ?? income.amount) > 0
      ).toList();
      
      final validExpenses = expenses.where((expense) => 
        expense.uuid != null && 
        expense.uuid!.isNotEmpty &&
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
        '✅ $createdCount pagamentos criados!\n${fullyPaidCount > 0 ? "$fullyPaidCount despesa(s) quitada(s)!" : ""}',
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
          _buildSectionHeader(
            icon: Icons.account_balance_wallet,
            title: 'Receitas Disponíveis',
            color: AppColors.success,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          if (_availableIncomes.isEmpty)
            _buildEmptyCard('Nenhuma receita disponível', theme, tokens)
          else
            ..._availableIncomes.map((income) => _buildIncomeCard(income, theme, tokens)),
          
          const SizedBox(height: 24),
          
          // Seção de Despesas
          _buildSectionHeader(
            icon: Icons.receipt_long,
            title: 'Despesas Pendentes',
            color: AppColors.alert,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          if (_pendingExpenses.isEmpty)
            _buildEmptyCard('Nenhuma despesa pendente', theme, tokens)
          else
            ..._pendingExpenses.map((expense) => _buildExpenseCard(expense, theme, tokens)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message, ThemeData theme, AppDecorations tokens) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeCard(TransactionModel income, ThemeData theme, AppDecorations tokens) {
    // Validar UUID disponível
    if (income.uuid == null || income.uuid!.isEmpty) {
      return const SizedBox.shrink(); // Não exibir se não tiver UUID
    }
    
    final incomeKey = income.uuid!;
    final isSelected = _selectedIncomes.containsKey(incomeKey);
    final available = income.availableAmount ?? income.amount;
    final selectedAmount = _selectedIncomes[incomeKey] ?? available;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.success.withOpacity(0.15) 
            : const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: isSelected ? AppColors.success : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: tokens.cardRadius,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIncomes.remove(incomeKey);
              } else {
                _selectedIncomes[incomeKey] = available;
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedIncomes[incomeKey] = available;
                          } else {
                            _selectedIncomes.remove(incomeKey);
                          }
                        });
                      },
                      activeColor: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            income.description,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Disponível: ${_currency.format(available)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currency.format(income.amount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                
                // Campo de valor quando selecionado
                if (isSelected) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Usar:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(maxDigits: 12),
                          ],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            prefixText: 'R\$ ',
                            prefixStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                            hintText: '0,00',
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          controller: TextEditingController(
                            text: CurrencyInputFormatter.format(selectedAmount),
                          )..selection = TextSelection.collapsed(
                              offset: CurrencyInputFormatter.format(selectedAmount).length,
                            ),
                          onChanged: (value) {
                            final cleanValue = value.replaceAll('.', '').replaceAll(',', '.');
                            final amount = double.tryParse(cleanValue) ?? 0.0;
                            
                            // Validar limites
                            if (amount < 0) return;
                            if (amount > 999999999.99) return;
                            
                            setState(() {
                              final limitedAmount = amount > available ? available : amount;
                              // Não permitir valor zero se selecionado
                              if (limitedAmount > 0) {
                                _selectedIncomes[incomeKey] = limitedAmount;
                              } else {
                                _selectedIncomes.remove(incomeKey);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIncomes[incomeKey] = available;
                          });
                        },
                        child: const Text('Máx'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(TransactionModel expense, ThemeData theme, AppDecorations tokens) {
    // Validar UUID disponível
    if (expense.uuid == null || expense.uuid!.isEmpty) {
      return const SizedBox.shrink(); // Não exibir se não tiver UUID
    }
    
    final expenseKey = expense.uuid!;
    final isSelected = _selectedExpenses.containsKey(expenseKey);
    final remaining = expense.availableAmount ?? expense.amount;
    final selectedAmount = _selectedExpenses[expenseKey] ?? remaining;
    final paymentPercentage = expense.linkPercentage ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.alert.withOpacity(0.15) 
            : const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: isSelected ? AppColors.alert : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: tokens.cardRadius,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedExpenses.remove(expenseKey);
              } else {
                _selectedExpenses[expenseKey] = remaining;
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedExpenses[expenseKey] = remaining;
                          } else {
                            _selectedExpenses.remove(expenseKey);
                          }
                        });
                      },
                      activeColor: AppColors.alert,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.description,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Pendente: ${_currency.format(remaining)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.alert,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (paymentPercentage > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: paymentPercentage >= 80
                                        ? AppColors.success.withOpacity(0.2)
                                        : AppColors.highlight.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${paymentPercentage.toStringAsFixed(0)}% pago',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: paymentPercentage >= 80
                                          ? AppColors.success
                                          : AppColors.highlight,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currency.format(expense.amount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                
                // Barra de progresso
                if (paymentPercentage > 0) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: paymentPercentage / 100,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        paymentPercentage >= 80 ? AppColors.success : AppColors.highlight,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
                
                // Campo de valor quando selecionado
                if (isSelected) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Pagar:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(maxDigits: 12),
                          ],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            prefixText: 'R\$ ',
                            prefixStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                            hintText: '0,00',
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          controller: TextEditingController(
                            text: CurrencyInputFormatter.format(selectedAmount),
                          )..selection = TextSelection.collapsed(
                              offset: CurrencyInputFormatter.format(selectedAmount).length,
                            ),
                          onChanged: (value) {
                            final cleanValue = value.replaceAll('.', '').replaceAll(',', '.');
                            final amount = double.tryParse(cleanValue) ?? 0.0;
                            
                            // Validar limites
                            if (amount < 0) return;
                            if (amount > 999999999.99) return;
                            
                            setState(() {
                              final limitedAmount = amount > remaining ? remaining : amount;
                              // Não permitir valor zero se selecionado
                              if (limitedAmount > 0) {
                                _selectedExpenses[expenseKey] = limitedAmount;
                              } else {
                                _selectedExpenses.remove(expenseKey);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedExpenses[expenseKey] = remaining;
                          });
                        },
                        child: const Text('Quitar'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Selecionado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _currency.format(_totalIncomeSelected),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _currency.format(_totalExpensesSelected),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.alert,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Saldo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currency.format(_balance),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _balance >= 0 ? AppColors.success : AppColors.alert,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
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
