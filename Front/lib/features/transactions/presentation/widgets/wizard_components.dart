import 'package:flutter/material.dart';

import '../../../../core/models/category.dart';
import '../../../../core/theme/app_colors.dart';

/// Card para seleção de tipo de transação (Receita/Despesa).
class TransactionTypeCard extends StatelessWidget {
  /// Cria um card de tipo de transação.
  const TransactionTypeCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.examples,
    required this.isSelected,
    required this.onTap,
  });

  /// Ícone do tipo.
  final IconData icon;

  /// Cor do ícone.
  final Color iconColor;

  /// Título do card.
  final String title;

  /// Subtítulo do card.
  final String subtitle;

  /// Exemplos de uso.
  final String examples;

  /// Se o card está selecionado.
  final bool isSelected;

  /// Callback ao tocar no card.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withOpacity(0.1) : Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? iconColor : Colors.grey[800]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    examples,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}

/// Card para seleção de categoria.
class TransactionCategoryCard extends StatelessWidget {
  /// Cria um card de categoria.
  const TransactionCategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  /// Modelo da categoria.
  final CategoryModel category;

  /// Se o card está selecionado.
  final bool isSelected;

  /// Callback ao tocar no card.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.color != null
        ? Color(
            int.parse(category.color!.substring(1), radix: 16) + 0xFF000000,
          )
        : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[800]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.category,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

/// Botão de ação rápida para valores.
class QuickAmountButton extends StatelessWidget {
  /// Cria um botão de valor rápido.
  const QuickAmountButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  /// Rótulo do botão.
  final String label;

  /// Callback ao tocar.
  final VoidCallback onTap;

  /// Se é uma ação destrutiva (estilo diferente).
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.alert.withOpacity(0.1)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDestructive ? AppColors.alert : Colors.grey[800]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDestructive ? AppColors.alert : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Linha de resumo para exibir dados da transação.
class TransactionSummaryRow extends StatelessWidget {
  /// Cria uma linha de resumo.
  const TransactionSummaryRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  /// Rótulo da linha.
  final String label;

  /// Valor a ser exibido.
  final String value;

  /// Ícone da linha.
  final IconData icon;

  /// Cor do ícone.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
