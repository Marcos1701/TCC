import 'package:flutter/material.dart';

import '../../../../core/models/mission.dart';
import 'mission_progress_detail_widget.dart';

/// Bottom sheet para exibir lista de missões filtradas.
class MissionListSheet extends StatefulWidget {
  const MissionListSheet({
    super.key,
    required this.title,
    required this.loader,
  });

  final String title;
  final Future<List<MissionModel>> Function() loader;

  @override
  State<MissionListSheet> createState() => _MissionListSheetState();
}

class _MissionListSheetState extends State<MissionListSheet> {
  late Future<List<MissionModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _retry() {
    setState(() {
      _future = widget.loader();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF06060C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Toque para abrir os detalhes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<MissionModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return MissionListError(onRetry: _retry);
                    }
                    final missions = snapshot.data ?? const [];
                    if (missions.isEmpty) {
                      return const MissionListEmpty();
                    }
                    return ListView.separated(
                      controller: controller,
                      itemCount: missions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final mission = missions[index];
                        return MissionListTile(mission: mission);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget de erro para lista de missões.
class MissionListError extends StatelessWidget {
  const MissionListError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 32),
          const SizedBox(height: 12),
          Text(
            'Não foi possível carregar as missões.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

/// Widget de estado vazio para lista de missões.
class MissionListEmpty extends StatelessWidget {
  const MissionListEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white38, size: 32),
          const SizedBox(height: 12),
          Text(
            'Nenhuma missão disponível para este filtro.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile para exibir uma missão na lista.
class MissionListTile extends StatelessWidget {
  const MissionListTile({super.key, required this.mission});

  final MissionModel mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${mission.rewardPoints} pts',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mission.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          MissionProgressDetailWidget(mission: mission, compact: true),
        ],
      ),
    );
  }
}
