import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/currency_input_formatter.dart';

/// Tipo de card de pagamento.
enum PaymentCardType {
  /// Receita (entrada de dinheiro).
  income,
  
  /// Despesa (saída de dinheiro).
  expense,
}

/// Card de transação para seleção em pagamentos em lote.
/// 
/// Exibe informações de receita ou despesa com opção de seleção
/// e campo de valor customizável.
class PaymentTransactionCard extends StatelessWidget {
  /// Cria um card de transação para pagamento.
  const PaymentTransactionCard({
    super.key,
    required this.transaction,
    required this.type,
    required this.isSelected,
    required this.selectedAmount,
    required this.onToggle,
    required this.onAmountChanged,
    required this.onMaxPressed,
    required this.tokens,
  });

  /// Transação a ser exibida.
  final TransactionModel transaction;

  /// Tipo do card (receita ou despesa).
  final PaymentCardType type;

  /// Se a transação está selecionada.
  final bool isSelected;

  /// Valor selecionado atual.
  final double selectedAmount;

  /// Callback ao alternar seleção.
  final VoidCallback onToggle;

  /// Callback quando o valor muda.
  final ValueChanged<double> onAmountChanged;

  /// Callback ao pressionar botão de valor máximo.
  final VoidCallback onMaxPressed;

  /// Design tokens do tema.
  final AppDecorations tokens;

  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  Color get _accentColor => type == PaymentCardType.income 
      ? AppColors.success 
      : AppColors.alert;

  String get _availableLabel => type == PaymentCardType.income 
      ? 'Disponível' 
      : 'Pendente';

  String get _actionLabel => type == PaymentCardType.income 
      ? 'Usar' 
      : 'Pagar';

  String get _maxButtonLabel => type == PaymentCardType.income 
      ? 'Máx' 
      : 'Quitar';

  @override
  Widget build(BuildContext context) {
    // Validar ID disponível
    if (transaction.id.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);
    final available = transaction.availableAmount ?? transaction.amount;
    final paymentPercentage = transaction.linkPercentage ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? _accentColor.withOpacity(0.15) 
            : const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
        border: Border.all(
          color: isSelected ? _accentColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: tokens.cardRadius,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, available, paymentPercentage),
                
                // Barra de progresso (apenas para despesas)
                if (type == PaymentCardType.expense && paymentPercentage > 0) 
                  _buildProgressBar(paymentPercentage),
                
                // Campo de valor quando selecionado
                if (isSelected) _buildValueInput(theme, available),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, double available, double paymentPercentage) {
    return Row(
      children: [
        Checkbox(
          value: isSelected,
          onChanged: (_) => onToggle(),
          activeColor: _accentColor,
        ),
        const SizedBox(width: 8),
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
              Row(
                children: [
                  Text(
                    '$_availableLabel: ${_currency.format(available)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (type == PaymentCardType.expense && paymentPercentage > 0) ...[
                    const SizedBox(width: 8),
                    _buildPercentageBadge(theme, paymentPercentage),
                  ],
                ],
              ),
            ],
          ),
        ),
        Text(
          _currency.format(transaction.amount),
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPercentageBadge(ThemeData theme, double percentage) {
    final isHighProgress = percentage >= 80;
    final badgeColor = isHighProgress ? AppColors.success : AppColors.highlight;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${percentage.toStringAsFixed(0)}% pago',
        style: theme.textTheme.bodySmall?.copyWith(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressBar(double percentage) {
    final isHighProgress = percentage >= 80;
    
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(
            isHighProgress ? AppColors.success : AppColors.highlight,
          ),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _buildValueInput(ThemeData theme, double available) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '$_actionLabel:',
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
                  
                  final limitedAmount = amount > available ? available : amount;
                  onAmountChanged(limitedAmount);
                },
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onMaxPressed,
              child: Text(_maxButtonLabel),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card vazio para exibir mensagem quando não há transações.
class EmptyTransactionCard extends StatelessWidget {
  /// Cria um card vazio.
  const EmptyTransactionCard({
    super.key,
    required this.message,
    required this.tokens,
  });

  /// Mensagem a ser exibida.
  final String message;

  /// Design tokens do tema.
  final AppDecorations tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
}

/// Header de seção para lista de transações.
class TransactionSectionHeader extends StatelessWidget {
  /// Cria um header de seção.
  const TransactionSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
  });

  /// Ícone da seção.
  final IconData icon;

  /// Título da seção.
  final String title;

  /// Cor do ícone.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
}

/// Resumo de valores selecionados para pagamento.
class PaymentSummaryRow extends StatelessWidget {
  /// Cria uma linha de resumo.
  const PaymentSummaryRow({
    super.key,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.balance,
  });

  /// Total de receitas selecionadas.
  final double incomeTotal;

  /// Total de despesas selecionadas.
  final double expenseTotal;

  /// Saldo restante.
  final double balance;

  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
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
                  _currency.format(incomeTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                const SizedBox(width: 8),
                Text(
                  _currency.format(expenseTotal),
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
              _currency.format(balance),
              style: theme.textTheme.titleMedium?.copyWith(
                color: balance >= 0 ? AppColors.success : AppColors.alert,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
