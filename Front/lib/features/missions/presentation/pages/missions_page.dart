import 'package:flutter/material.dart';

class MissionsPage extends StatelessWidget {
  const MissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _mockMissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final mission = _mockMissions[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      mission.icon,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mission.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Chip(
                      label: Text('${mission.reward} pts'),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mission.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: mission.progress,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text('${(mission.progress * 100).round()}% concluído'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: mission.progress >= 1 ? null : () {},
                  child: Text(mission.progress >= 1 ? 'Missão concluída' : 'Atualizar progresso'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MissionItem {
  const _MissionItem({
    required this.title,
    required this.description,
    required this.progress,
    required this.reward,
    required this.icon,
  });

  final String title;
  final String description;
  final double progress;
  final int reward;
  final IconData icon;
}

const _mockMissions = <_MissionItem>[
  _MissionItem(
    title: 'Controle semanal de gastos',
    description:
        'Registre todas as despesas por 7 dias consecutivos para identificar padrões de consumo.',
    progress: 0.6,
    reward: 120,
    icon: Icons.timeline_outlined,
  ),
  _MissionItem(
    title: 'Negociação de dívidas',
    description:
        'Liste suas dívidas, priorize os maiores juros e crie um plano usando os métodos bola de neve ou avalanche.',
    progress: 0.2,
    reward: 200,
    icon: Icons.handshake_outlined,
  ),
  _MissionItem(
    title: 'Reserva de emergência',
    description: 'Aumente sua reserva para o equivalente a 2 meses de despesas essenciais.',
    progress: 0.85,
    reward: 180,
    icon: Icons.savings_outlined,
  ),
];
