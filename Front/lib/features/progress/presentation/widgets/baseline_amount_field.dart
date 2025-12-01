import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/goal.dart';

/// Campo de entrada para baseline amount com label e help text dinâmicos por tipo de meta
class BaselineAmountField extends StatelessWidget {
  const BaselineAmountField({
    super.key,
    required this.controller,
    required this.goalType,
  });

  final TextEditingController controller;
  final GoalType goalType;

  @override
  Widget build(BuildContext context) {
    String label;
    String hint;
    String helpText;

    switch (goalType) {
      case GoalType.expenseReduction:
        label = 'Gasto Médio Mensal Atual';
        hint = 'Quanto você gasta por mês atualmente?';
        helpText = 'Informe o valor médio mensal que você gasta nesta categoria atualmente. '
            'Este valor será usado como referência para calcular o progresso.';
        break;
      case GoalType.incomeIncrease:
        label = 'Receita Média Mensal Atual';
        hint = 'Quanto você ganha por mês atualmente?';
        helpText = 'Informe sua receita média mensal atual. '
            'Este valor será usado como referência para calcular o aumento alcançado.';
        break;
      default:
        return const SizedBox.shrink(); // Não mostrar para outros tipos
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  helpText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: hint,
            prefixText: 'R\$ ',
            prefixStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo é obrigatório';
            }
            final amount = double.tryParse(value.replaceAll(',', '.'));
            if (amount == null || amount <= 0) {
              return 'Informe um valor válido maior que zero';
            }
            return null;
          },
        ),
        const SizedBox(height: 4),
        Text(
          goalType == GoalType.expenseReduction
              ? 'Exemplo: Se você gasta R\$ 800/mês em alimentação, digite 800'
              : 'Exemplo: Se você ganha R\$ 3000/mês, digite 3000',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}
