import 'package:flutter/material.dart';
import '../../data/missions_viewmodel.dart';

/// Widget de monitoramento de qualidade de missões (debug/admin)
class MissionQualityMonitor extends StatelessWidget {
  final MissionsViewModel viewModel;
  final bool alwaysShow;

  const MissionQualityMonitor({
    super.key,
    required this.viewModel,
    this.alwaysShow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final stats = viewModel.missionQualityStats;
        final invalidCount = stats['invalid'] as int;

        // Só mostra se houver problemas ou se alwaysShow = true
        if (!alwaysShow && invalidCount == 0) {
          return const SizedBox.shrink();
        }

        final qualityRate = double.parse(stats['quality_rate'] as String);
        final isHealthy = qualityRate >= 95.0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHealthy
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.15),
            border: Border.all(
              color: isHealthy ? Colors.green : Colors.orange,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                color: isHealthy ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qualidade dos Dados: ${stats['quality_rate']}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (invalidCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$invalidCount missão(ões) com placeholders filtrada(s)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${stats['valid']}/${stats['total']}',
                style: TextStyle(
                  color: isHealthy ? Colors.green : Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
