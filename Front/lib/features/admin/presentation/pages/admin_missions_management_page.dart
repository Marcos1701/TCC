import 'package:flutter/material.dart';
import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

/// Página para gerenciar missões (CRUD)
class AdminMissionsManagementPage extends StatefulWidget {
  const AdminMissionsManagementPage({super.key});

  @override
  State<AdminMissionsManagementPage> createState() =>
      _AdminMissionsManagementPageState();
}

class _AdminMissionsManagementPageState
    extends State<AdminMissionsManagementPage> {
  final _apiClient = ApiClient();
  bool _isLoading = true;
  List<Map<String, dynamic>> _missions = [];
  String? _error;
  String _filterType = 'ALL';
  String _filterDifficulty = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.client.get(
        '/api/missions/',
      );

      if (response.data != null) {
        final data = response.data is Map<String, dynamic> 
            ? response.data as Map<String, dynamic>
            : json.decode(response.data.toString()) as Map<String, dynamic>;
        
        final results = data['results'] as List?;
        setState(() {
          _missions = results?.cast<Map<String, dynamic>>() ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMissionStatus(String missionId, bool isActive) async {
    try {
      await _apiClient.client.patch(
        '/api/missions/$missionId/',
        data: {'is_active': !isActive},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive ? 'Missão desativada' : 'Missão ativada',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadMissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMissions {
    return _missions.where((mission) {
      final typeMatch = _filterType == 'ALL' ||
          mission['mission_type'] == _filterType;
      final difficultyMatch = _filterDifficulty == 'ALL' ||
          mission['priority'] == _filterDifficulty;
      return typeMatch && difficultyMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Gerenciar Missões',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMissions,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : _buildMissionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _filterType,
                      dropdownColor: const Color(0xFF2A2A2A),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        isDense: true,
                      ),
                      style: TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'SAVINGS',
                          child: Text('Economia'),
                        ),
                        DropdownMenuItem(
                          value: 'EXPENSE_CONTROL',
                          child: Text('Controle'),
                        ),
                        DropdownMenuItem(
                          value: 'DEBT_REDUCTION',
                          child: Text('Dívidas'),
                        ),
                        DropdownMenuItem(
                          value: 'ONBOARDING',
                          child: Text('Onboarding'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterType = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dificuldade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _filterDifficulty,
                      dropdownColor: const Color(0xFF2A2A2A),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        isDense: true,
                      ),
                      style: TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Todas')),
                        DropdownMenuItem(value: 'EASY', child: Text('Fácil')),
                        DropdownMenuItem(
                          value: 'MEDIUM',
                          child: Text('Média'),
                        ),
                        DropdownMenuItem(value: 'HARD', child: Text('Difícil')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterDifficulty = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_filteredMissions.length} missões encontradas',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.alert.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar missões',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMissions,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionsList() {
    if (_filteredMissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma missão encontrada',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _filteredMissions.length,
      itemBuilder: (context, index) {
        final mission = _filteredMissions[index];
        final missionId = mission['id']?.toString() ?? '';
        final isActive = mission['is_active'] as bool? ?? true;
        return _MissionCard(
          mission: mission,
          onToggleStatus: () => _toggleMissionStatus(missionId, !isActive),
        );
      },
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.onToggleStatus,
  });

  final Map<String, dynamic> mission;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final isActive = mission['is_active'] as bool? ?? true;
    final type = mission['mission_type'] as String? ?? '';
    final difficulty = mission['difficulty'] as String? ?? mission['priority'] as String? ?? '';
    final xp = mission['reward_points'] ?? mission['xp_reward'] ?? 0;
    final duration = mission['duration_days'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mission['title'] as String? ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Switch(
                    value: isActive,
                    onChanged: (_) => onToggleStatus(),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mission['description'] as String? ?? '',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.category,
                    label: _getTypeLabel(type),
                    color: _getTypeColor(type),
                  ),
                  _InfoChip(
                    icon: Icons.signal_cellular_alt,
                    label: _getDifficultyLabel(difficulty),
                    color: _getDifficultyColor(difficulty),
                  ),
                  _InfoChip(
                    icon: Icons.star,
                    label: '$xp XP',
                    color: Colors.amber,
                  ),
                  if (duration != null && duration > 0)
                    _InfoChip(
                      icon: Icons.calendar_today,
                      label: '$duration dias',
                      color: Colors.blue,
                    ),
                ],
              ),
              if (mission['target_tps'] != null ||
                  mission['target_rdr'] != null ||
                  mission['min_ili'] != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (mission['target_tps'] != null)
                      _MetricChip(
                        label: 'TPS: ${mission['target_tps']}%',
                        color: Colors.green,
                      ),
                    if (mission['target_rdr'] != null)
                      _MetricChip(
                        label: 'RDR: ${mission['target_rdr']}%',
                        color: Colors.orange,
                      ),
                    if (mission['min_ili'] != null)
                      _MetricChip(
                        label: 'ILI: ${mission['min_ili']} meses',
                        color: Colors.purple,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'SAVINGS':
        return 'Economia';
      case 'EXPENSE_CONTROL':
        return 'Controle';
      case 'DEBT_REDUCTION':
        return 'Dívidas';
      case 'ONBOARDING':
        return 'Onboarding';
      default:
        return type;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'SAVINGS':
        return Colors.green;
      case 'EXPENSE_CONTROL':
        return Colors.blue;
      case 'DEBT_REDUCTION':
        return Colors.orange;
      case 'ONBOARDING':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getDifficultyLabel(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return 'Fácil';
      case 'MEDIUM':
        return 'Média';
      case 'HARD':
        return 'Difícil';
      default:
        return difficulty;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HARD':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
