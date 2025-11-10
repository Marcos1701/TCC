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
  List<TransactionModel> _pendingDebts = [];
  
  // Seleções (Map<transactionId, amount>)
  final Map<String, double> _selectedIncomes = {};
  final Map<String, double> _selectedDebts = {};
  
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
      final debts = await _repository.fetchPendingDebts();

      if (!mounted) return;
      setState(() {
        _availableIncomes = incomes;
        _pendingDebts = debts;
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
  double get _totalDebtsSelected => _selectedDebts.values.fold(0.0, (a, b) => a + b);
  double get _balance => _totalIncomeSelected - _totalDebtsSelected;
  
  bool get _canSubmit => 
      _selectedIncomes.isNotEmpty && 
      _selectedDebts.isNotEmpty && 
      _balance >= 0;

  Future<void> _submitPayments() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      // Montar lista de pagamentos
      final payments = <Map<String, dynamic>>[];
      
      // Para cada despesa selecionada, distribuir pagamento das receitas
      for (final debtEntry in _selectedDebts.entries) {
        final debtUuid = debtEntry.key;
        final debtAmount = debtEntry.value;
        double remainingToAllocate = debtAmount;
        
        // Distribuir entre as receitas selecionadas
        for (final incomeEntry in _selectedIncomes.entries) {
          if (remainingToAllocate <= 0) break;
          
          final incomeUuid = incomeEntry.key;
          final incomeAvailable = incomeEntry.value;
          
          // Quanto alocar desta receita para esta despesa
          final allocateAmount = remainingToAllocate < incomeAvailable 
              ? remainingToAllocate 
              : incomeAvailable;
          
          if (allocateAmount > 0) {
            payments.add({
              'source_id': incomeUuid,
              'target_id': debtUuid,
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
      final fullyPaidCount = (result['summary']?['fully_paid_debts'] as List?)?.length ?? 0;
      
      FeedbackService.showSuccess(
        context,
        '✅ $createdCount pagamentos criados!\n${fullyPaidCount > 0 ? "$fullyPaidCount despesa(s) quitada(s)!" : ""}',
      );

      // Voltar para tela anterior
      Navigator.of(context).pop(true);

    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isSubmitting = false);
      
      FeedbackService.showError(
        context,
        'Erro ao processar pagamentos: $e',
      );
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
    if (_availableIncomes.isEmpty && _pendingDebts.isEmpty) {
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
          
          if (_pendingDebts.isEmpty)
            _buildEmptyCard('Nenhuma despesa pendente', theme, tokens)
          else
            ..._pendingDebts.map((debt) => _buildDebtCard(debt, theme, tokens)),
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
    final incomeKey = income.uuid ?? income.id.toString();
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
                            setState(() {
                              _selectedIncomes[incomeKey] = 
                                  amount > available ? available : amount;
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

  Widget _buildDebtCard(TransactionModel debt, ThemeData theme, AppDecorations tokens) {
    final debtKey = debt.uuid ?? debt.id.toString();
    final isSelected = _selectedDebts.containsKey(debtKey);
    final remaining = debt.availableAmount ?? debt.amount;
    final selectedAmount = _selectedDebts[debtKey] ?? remaining;
    final paymentPercentage = debt.linkPercentage ?? 0.0;

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
                _selectedDebts.remove(debtKey);
              } else {
                _selectedDebts[debtKey] = remaining;
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
                            _selectedDebts[debtKey] = remaining;
                          } else {
                            _selectedDebts.remove(debtKey);
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
                            debt.description,
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
                      _currency.format(debt.amount),
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
                            setState(() {
                              _selectedDebts[debtKey] = 
                                  amount > remaining ? remaining : amount;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDebts[debtKey] = remaining;
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
                          _currency.format(_totalDebtsSelected),
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
                            'Confirmar Pagamento${_selectedDebts.length > 1 ? "s" : ""} (${_selectedDebts.length})',
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
            if (!_canSubmit && (_selectedIncomes.isNotEmpty || _selectedDebts.isNotEmpty))
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
