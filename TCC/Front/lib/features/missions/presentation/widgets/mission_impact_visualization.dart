import 'package:flutter/material.dart';

import '../../../../core/services/analytics_service.dart';
import '../../data/missions_viewmodel.dart';

class MissionImpactVisualization extends StatefulWidget {
  const MissionImpactVisualization({
    super.key,
    required this.viewModel,
  });

  final MissionsViewModel viewModel;

  @override
  State<MissionImpactVisualization> createState() =>
      _MissionImpactVisualizationState();
}

class _MissionImpactVisualizationState
    extends State<MissionImpactVisualization> {
  bool _requestedLoad = false;
  bool _trackedInitialSnapshot = false;
  bool _refreshRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureData());
  }

  @override
  void didUpdateWidget(covariant MissionImpactVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _requestedLoad = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureData());
    }
  }

  void _ensureData() {
    if (_requestedLoad) return;
    _requestedLoad = true;
    widget.viewModel.refreshMissionContextAnalysis();
  }

  void _maybeTrackSnapshot(int indicatorCount, int opportunityCount) {
    final shouldTrack = !_trackedInitialSnapshot || _refreshRequested;
    if (!shouldTrack) return;
    AnalyticsService.trackMissionContextSnapshot(
      indicatorCount: indicatorCount,
      opportunityCount: opportunityCount,
      fromRefresh: _refreshRequested,
    );
    _trackedInitialSnapshot = true;
    _refreshRequested = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final data = widget.viewModel.missionContextAnalysis;
        final isLoading = widget.viewModel.isContextLoading;
        final error = widget.viewModel.contextError;

        if (isLoading && data == null) {
          return const _MissionImpactSkeleton();
        }

        if (error != null && data == null) {
          return _MissionImpactError(
            message: error,
            onRetry: _onRetry,
          );
        }

        if (data == null) {
          return const SizedBox.shrink();
        }

        final indicators = _parseIndicators(data['indicators']);
        final opportunities =
            _parseOpportunities(data['opportunities'] ?? data['hotspots']);
        if (indicators.isEmpty && opportunities.isEmpty) {
          return _MissionImpactError(
            message:
                'Sem dados suficientes. Continue registrando suas movimentações.',
            onRetry: _onRetry,
            compact: true,
          );
        }

        _maybeTrackSnapshot(indicators.length, opportunities.length);

        return _MissionImpactContent(
          indicators: indicators,
          opportunities: opportunities,
          refreshing: isLoading,
          onRefresh: _onRetry,
        );
      },
    );
  }

  void _onRetry() {
    _refreshRequested = true;
    AnalyticsService.trackMissionContextRefreshRequested();
    widget.viewModel.refreshMissionContextAnalysis(forceRefresh: true);
  }
}

class _MissionImpactContent extends StatelessWidget {
  const _MissionImpactContent({
    required this.indicators,
    required this.opportunities,
    required this.refreshing,
    required this.onRefresh,
  });

  final List<_IndicatorSnapshot> indicators;
  final List<_OpportunityInsight> opportunities;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impacto atual',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Veja onde agir agora.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          if (indicators.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: indicators
                  .map((indicator) => _IndicatorCard(snapshot: indicator))
                  .toList(),
            ),
          ],
          if (opportunities.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Próximos ajustes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...opportunities.take(3).map(
                  (op) => _OpportunityCard(opportunity: op),
                ),
          ],
        ],
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.snapshot});

  final _IndicatorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = snapshot.progress;

    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(snapshot.icon, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  snapshot.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor:
                    AlwaysStoppedAnimation<Color>(snapshot.accentColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.progressLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity});

  final _OpportunityInsight opportunity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161621),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(opportunity.icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  opportunity.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (opportunity.deltaLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: opportunity.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    opportunity.deltaLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: opportunity.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            opportunity.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              height: 1.3,
            ),
          ),
          if (opportunity.nextStep != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    opportunity.nextStep!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionImpactSkeleton extends StatelessWidget {
  const _MissionImpactSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissionImpactError extends StatelessWidget {
  const _MissionImpactError({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 12 : 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sem análise disponível',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Atualizar análise'),
          ),
        ],
      ),
    );
  }
}

class _IndicatorSnapshot {
  const _IndicatorSnapshot({
    required this.label,
    required this.summary,
    required this.icon,
    required this.accentColor,
    this.current,
    this.target,
  });

  final String label;
  final String summary;
  final IconData icon;
  final Color accentColor;
  final double? current;
  final double? target;

  double? get progress {
    if (current == null || target == null || target == 0) {
      return null;
    }
    return (current! / target!).clamp(0.0, 1.0);
  }

  String get progressLabel {
    if (current == null || target == null) {
      return 'Acompanhe as próximas movimentações';
    }
    final currentPercent = (current! * 100).toStringAsFixed(0);
    final targetPercent = (target! * 100).toStringAsFixed(0);
    return '$currentPercent% de $targetPercent% planejado';
  }
}

class _OpportunityInsight {
  const _OpportunityInsight({
    required this.title,
    required this.detail,
    required this.icon,
    required this.accentColor,
    this.deltaLabel,
    this.nextStep,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color accentColor;
  final String? deltaLabel;
  final String? nextStep;
}

List<_IndicatorSnapshot> _parseIndicators(dynamic raw) {
  if (raw is Map) {
    return raw.entries.map((entry) {
      final value = entry.value;
        final Map<String, dynamic> data = value is Map
          ? Map<String, dynamic>.from(value)
          : {'current': value};
      return _IndicatorSnapshot(
        label: entry.key.toString(),
        summary: _buildIndicatorSummary(entry.key.toString(), data),
        icon: _indicatorIcon(entry.key.toString()),
        accentColor: _indicatorColor(entry.key.toString()),
        current: _toDouble(data['current']),
        target: _toDouble(data['target']),
      );
    }).toList();
  }
  return const [];
}

List<_OpportunityInsight> _parseOpportunities(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return _OpportunityInsight(
        title: map['title'] as String? ?? 'Oportunidade',
        detail: map['detail'] as String? ??
            (map['description'] as String? ?? 'Sem detalhes disponíveis'),
        deltaLabel: map['delta']?.toString(),
        nextStep: map['next_step'] as String?,
        icon: _opportunityIcon(map['metric'] as String?),
        accentColor: _opportunityColor(map['metric'] as String?),
      );
    }).toList();
  }
  return const [];
}

String _buildIndicatorSummary(String key, Map<String, dynamic> data) {
  final current = _toDouble(data['current']);
  final target = _toDouble(data['target']);
  if (current == null) {
    return 'Sem histórico recente';
  }
  final percent = (current * 100).toStringAsFixed(0);
  if (target == null) {
    return '$percent% registrado';
  }
  final targetPercent = (target * 100).toStringAsFixed(0);
  return '$percent% de $targetPercent% planejado';
}

IconData _indicatorIcon(String key) {
  switch (key.toUpperCase()) {
    case 'TPS':
      return Icons.savings_outlined;
    case 'RDR':
      return Icons.trending_down;
    case 'ILI':
      return Icons.shield_moon_outlined;
    default:
      return Icons.assessment_outlined;
  }
}

Color _indicatorColor(String key) {
  switch (key.toUpperCase()) {
    case 'TPS':
      return const Color(0xFF4CAF50);
    case 'RDR':
      return const Color(0xFFF44336);
    case 'ILI':
      return const Color(0xFF00BCD4);
    default:
      return const Color(0xFFFFC107);
  }
}

IconData _opportunityIcon(String? metric) {
  switch ((metric ?? '').toUpperCase()) {
    case 'CATEGORY':
      return Icons.category_outlined;
    case 'PAYMENT':
      return Icons.receipt_long_outlined;
    default:
      return Icons.task_alt_outlined;
  }
}

Color _opportunityColor(String? metric) {
  switch ((metric ?? '').toUpperCase()) {
    case 'CATEGORY':
      return const Color(0xFFFFC107);
    case 'PAYMENT':
      return const Color(0xFF2196F3);
    default:
      return const Color(0xFF9C27B0);
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
