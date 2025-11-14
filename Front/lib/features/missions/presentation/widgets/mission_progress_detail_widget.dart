import 'package:flutter/material.dart';

import '../../../../core/models/mission.dart';

class MissionProgressDetailWidget extends StatelessWidget {
  const MissionProgressDetailWidget({
    super.key,
    required this.mission,
    this.compact = false,
  });

  final MissionModel mission;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _buildRows();
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleRows = compact ? rows.take(2).toList() : rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleRows
          .map(
            (descriptor) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      descriptor.icon,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          descriptor.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          descriptor.detail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  List<_ProgressDescriptor> _buildRows() {
    final rows = <_ProgressDescriptor>[];

    final goalSummary = _buildGoalSummary();
    if (goalSummary != null) {
      rows.add(
        _ProgressDescriptor(
          label: 'O que precisa ser feito',
          detail: goalSummary,
          icon: Icons.flag_circle,
        ),
      );
    }

    final actionSummary = _buildActionSummary();
    if (actionSummary != null) {
      rows.add(
        _ProgressDescriptor(
          label: 'Como avançar',
          detail: actionSummary,
          icon: Icons.playlist_add_check,
        ),
      );
    }

    final trackingSummary = _buildTrackingSummary();
    if (trackingSummary != null) {
      rows.add(
        _ProgressDescriptor(
          label: 'Como o progresso é acompanhado',
          detail: trackingSummary,
          icon: Icons.insights,
        ),
      );
    }

    return rows;
  }

  String? _buildGoalSummary() {
    final targetInfo = mission.targetInfo;
    if (targetInfo is Map<String, dynamic>) {
      final headline = targetInfo['headline'];
      if (headline is String && headline.isNotEmpty) {
        return headline;
      }
      final targets = targetInfo['targets'];
      if (targets is List && targets.isNotEmpty) {
        final Map first = targets.first as Map;
        final label = first['label']?.toString();
        if (label != null && label.isNotEmpty) {
          return label;
        }
      }
    }

    if (mission.targetCategoryData != null &&
        mission.targetReductionPercent != null) {
      final percent = mission.targetReductionPercent!.toStringAsFixed(0);
      return 'Reduzir ${mission.targetCategoryData!.name} em $percent%';
    }

    if (mission.targetCategoryData != null && mission.categorySpendingLimit != null) {
      final limit = mission.categorySpendingLimit!.toStringAsFixed(0);
      return 'Manter ${mission.targetCategoryData!.name} abaixo de R\$ $limit';
    }

    if (mission.goalProgressTarget != null) {
      final percent = (mission.goalProgressTarget! * 100).toStringAsFixed(0);
      return 'Levar a meta selecionada para $percent% de conclusão';
    }

    return mission.description.isNotEmpty ? mission.description : null;
  }

  String? _buildActionSummary() {
    if (mission.tips != null && mission.tips!.isNotEmpty) {
      final text = mission.tips!.first['text'] as String?;
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    if (mission.minTransactionFrequency != null) {
      final frequency = mission.minTransactionFrequency!;
      final filter = mission.transactionTypeFilter ?? 'BOTH';
      final descriptor = filter == 'INCOME'
          ? 'receitas'
          : filter == 'EXPENSE'
              ? 'despesas'
              : 'transações';
      return 'Registre pelo menos $frequency $descriptor por semana.';
    }

    if (mission.requiresDailyAction == true && mission.minDailyActions != null) {
      return 'Complete ${mission.minDailyActions!} ações por dia durante ${mission.durationDays} dias.';
    }

    if (mission.requiresPaymentTracking && mission.minPaymentsCount != null) {
      return 'Confirme ${mission.minPaymentsCount!} pagamentos dentro do período.';
    }

    return null;
  }

  String? _buildTrackingSummary() {
    final buffer = StringBuffer();
    buffer.write(mission.validationTypeLabel);
    if (mission.durationDays > 0) {
      buffer.write(' em ${mission.durationDays} dias');
    }

    final needsFrequency = mission.requiresConsecutiveDays == true &&
        mission.minConsecutiveDays != null;
    if (needsFrequency) {
      buffer.write(
        ' mantendo ${mission.minConsecutiveDays} dia${mission.minConsecutiveDays == 1 ? '' : 's'} seguidos',
      );
    }

    return buffer.toString().trim().isEmpty ? null : buffer.toString();
  }
}

class _ProgressDescriptor {
  const _ProgressDescriptor({
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String detail;
  final IconData icon;
}
