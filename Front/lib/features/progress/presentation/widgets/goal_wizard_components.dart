import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Card para seleção de tipo de meta.
class GoalTypeCard extends StatelessWidget {
  /// Cria um card de tipo de meta.
  const GoalTypeCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.examples,
    required this.isSelected,
    required this.onTap,
  });

  /// Ícone do tipo de meta.
  final IconData icon;

  /// Cor do ícone.
  final Color iconColor;

  /// Título do card.
  final String title;

  /// Descrição do tipo de meta.
  final String description;

  /// Exemplos de uso.
  final String examples;

  /// Se o card está selecionado.
  final bool isSelected;

  /// Callback ao tocar no card.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected 
          ? AppColors.primary.withOpacity(0.2)
          : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
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
                child: Icon(icon, color: iconColor, size: 32),
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
                      description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      examples,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
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
  }
}

/// Chip de seleção de opção de prazo para metas.
class DeadlineOptionChip extends StatelessWidget {
  /// Cria um chip de opção de prazo.
  const DeadlineOptionChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  /// Rótulo do chip.
  final String label;

  /// Se está selecionado.
  final bool isSelected;

  /// Callback ao tocar.
  final VoidCallback onTap;

  /// Widget opcional à direita (ex: data selecionada).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary.withOpacity(0.2)
          : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
              if (isSelected && trailing == null)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de template para seleção de título de meta.
class TemplateChip extends StatelessWidget {
  /// Cria um chip de template.
  const TemplateChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// Rótulo do template.
  final String label;

  /// Se está selecionado.
  final bool isSelected;

  /// Callback ao tocar.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected 
          ? AppColors.primary.withOpacity(0.2)
          : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
