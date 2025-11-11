import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Dashboard Simples de Analytics (Dia 21-25)
/// 
/// Exibe métricas básicas de eventos rastreados localmente.
/// Em produção, poderia conectar com Firebase Analytics ou similar.
class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  late List<AnalyticsEvent> _events;
  late Map<String, int> _eventCounts;
  late Map<String, Duration> _screenTimes;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackScreenView('analytics_dashboard');
    _loadData();
  }

  void _loadData() {
    setState(() {
      _events = AnalyticsService.getEvents();
      _eventCounts = AnalyticsService.getEventCounts();
      _screenTimes = AnalyticsService.getScreenTimes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dados atualizados'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _events.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                _loadData();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  _buildEventCountsCard(),
                  const SizedBox(height: 16),
                  _buildScreenTimesCard(),
                  const SizedBox(height: 16),
                  _buildRecentEventsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum evento rastreado ainda',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use o app para começar a coletar dados',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final now = DateTime.now();
    final todayEvents = _events.where((event) {
      return event.timestamp.day == now.day &&
          event.timestamp.month == now.month &&
          event.timestamp.year == now.year;
    }).length;

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Resumo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Total de Eventos',
                    '${_events.length}',
                    Icons.event,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricItem(
                    'Hoje',
                    '$todayEvents',
                    Icons.today,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Tipos de Eventos',
                    '${_eventCounts.length}',
                    Icons.category,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricItem(
                    'Telas Visitadas',
                    '${_screenTimes.length}',
                    Icons.phone_android,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCountsCard() {
    final sortedCounts = _eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.leaderboard,
                  color: AppColors.support,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Top Eventos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedCounts.take(10).map((entry) {
              final maxCount = sortedCounts.first.value.toDouble();
              final progress = entry.value / maxCount;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatEventName(entry.key),
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTimesCard() {
    if (_screenTimes.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedTimes = _screenTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timer,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Tempo nas Telas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedTimes.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatScreenName(entry.key),
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatDuration(entry.value),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEventsCard() {
    final recentEvents = _events.reversed.take(15).toList();

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Colors.grey[400],
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Eventos Recentes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recentEvents.map((event) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: 12),
                      decoration: BoxDecoration(
                        color: _getEventColor(event.name),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatEventName(event.name),
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm:ss').format(event.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (event.parameters.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.parameters.entries
                                  .take(2)
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', '),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatEventName(String eventName) {
    return eventName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatScreenName(String screenName) {
    final names = {
      'unified_home': 'Início',
      'finances': 'Finanças',
      'profile': 'Perfil',
      'analytics_dashboard': 'Analytics',
      'leaderboard': 'Ranking',
      'missions': 'Missões',
      'transactions': 'Transações',
      'progress': 'Metas',
    };
    return names[screenName] ?? _formatEventName(screenName);
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}min ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Color _getEventColor(String eventName) {
    if (eventName.contains('screen')) return Colors.blue;
    if (eventName.contains('goal')) return Colors.green;
    if (eventName.contains('mission')) return Colors.purple;
    if (eventName.contains('friend')) return Colors.orange;
    if (eventName.contains('onboarding')) return Colors.cyan;
    if (eventName.contains('transaction')) return Colors.pink;
    if (eventName.contains('login') || eventName.contains('logout')) return Colors.red;
    return Colors.grey;
  }
}
