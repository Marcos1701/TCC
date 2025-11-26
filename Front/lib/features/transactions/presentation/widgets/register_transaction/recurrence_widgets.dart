import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import 'recurrence_models.dart';

export 'recurrence_models.dart';

/// Chip de opção de recorrência.
class RecurrenceOptionChip extends StatelessWidget {
  const RecurrenceOptionChip({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.isOutlined = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool isOutlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = selected
        ? AppColors.primary.withOpacity(0.16)
        : const Color(0xFF0B1020);
    final borderColor = selected
        ? AppColors.primary
        : (isOutlined
            ? Colors.white.withOpacity(0.24)
            : Colors.white.withOpacity(0.12));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de resumo da recorrência configurada.
class RecurrenceSummaryCard extends StatelessWidget {
  const RecurrenceSummaryCard({
    super.key,
    required this.summary,
    required this.onEdit,
    required this.hasSelection,
  });

  final String summary;
  final VoidCallback onEdit;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.repeat_rounded,
              color: Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (!hasSelection) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Escolha uma opção ou personalize para que o lançamento '
                    'se repita automaticamente.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }
}

/// Seletor de data final de recorrência.
class RecurrenceEndDatePicker extends StatelessWidget {
  const RecurrenceEndDatePicker({
    super.key,
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? 'Sem data final (continua até você remover)'
        : 'Até ${DateFormat('dd/MM/yyyy', 'pt_BR').format(date!)}';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.event_repeat_rounded),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white60,
            tooltip: 'Remover data final',
          ),
        ],
      ],
    );
  }
}

/// Painel de configuração de recorrência.
///
/// Agrupa os presets, resumo e seletor de data final.
class RecurrencePanel extends StatelessWidget {
  const RecurrencePanel({
    super.key,
    required this.recurrenceUnit,
    required this.recurrenceValue,
    required this.recurrenceEndDate,
    required this.usingCustomRecurrence,
    required this.recurrenceError,
    required this.onPresetSelected,
    required this.onCustomRecurrence,
    required this.onPickEndDate,
    required this.onClearEndDate,
    this.labelStyle,
  });

  final RecurrenceUnit? recurrenceUnit;
  final int? recurrenceValue;
  final DateTime? recurrenceEndDate;
  final bool usingCustomRecurrence;
  final String? recurrenceError;
  final void Function(RecurrenceUnit unit, int value) onPresetSelected;
  final VoidCallback onCustomRecurrence;
  final VoidCallback onPickEndDate;
  final VoidCallback onClearEndDate;
  final TextStyle? labelStyle;

  String? get _recurrenceSummary {
    if (recurrenceUnit == null || recurrenceValue == null) {
      return null;
    }
    final base = recurrenceUnit!.shortLabel(recurrenceValue!);
    if (recurrenceEndDate != null) {
      final formatted = DateFormat('dd/MM/yyyy', 'pt_BR').format(recurrenceEndDate!);
      return '$base até $formatted';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (labelStyle != null)
          Text(
            'Com que frequência repetir?',
            style: labelStyle,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in RecurrencePreset.defaults)
              RecurrenceOptionChip(
                title: preset.title,
                subtitle: preset.subtitle,
                selected: !usingCustomRecurrence &&
                    recurrenceUnit == preset.unit &&
                    recurrenceValue == preset.value,
                onTap: () => onPresetSelected(preset.unit, preset.value),
              ),
            RecurrenceOptionChip(
              title: 'Personalizar...',
              subtitle: 'Informe valor e unidade.',
              selected: usingCustomRecurrence,
              onTap: onCustomRecurrence,
              isOutlined: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        RecurrenceSummaryCard(
          summary: _recurrenceSummary ??
              'Escolha uma frequência para repetir automaticamente.',
          onEdit: onCustomRecurrence,
          hasSelection: _recurrenceSummary != null,
        ),
        if (recurrenceError != null) ...[
          const SizedBox(height: 8),
          Text(
            recurrenceError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.alert,
            ),
          ),
        ],
        const SizedBox(height: 12),
        RecurrenceEndDatePicker(
          date: recurrenceEndDate,
          onPick: onPickEndDate,
          onClear: onClearEndDate,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
