import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import 'admin_missions_management_page.dart';
import 'admin_categories_management_page.dart';
import 'admin_ai_missions_page.dart';

/// Dashboard principal de administração
/// 
/// Exibe métricas gerais do sistema:
/// - Total de usuários
/// - Missões completadas
/// - Evolução de usuários
/// - Estatísticas gerais
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _apiClient = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.client.get(
        '/api/admin-stats/overview/',
      );

      if (response.data != null) {
        // Debug: verificar tipo da resposta
        print('Response type: ${response.data.runtimeType}');
        print('Response data: ${response.data}');
        
        Map<String, dynamic> data;
        
        if (response.data is Map<String, dynamic>) {
          data = response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          data = json.decode(response.data.toString()) as Map<String, dynamic>;
        } else {
          throw Exception('Formato de resposta inesperado: ${response.data.runtimeType}');
        }
        
        setState(() {
          _stats = data;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      String errorMsg = 'Erro desconhecido';
      
      if (e.response != null) {
        print('Error status: ${e.response?.statusCode}');
        print('Error data: ${e.response?.data}');
        
        if (e.response?.statusCode == 403) {
          errorMsg = 'Acesso negado. Você precisa ser administrador.';
        } else if (e.response?.statusCode == 500) {
          final errorData = e.response?.data;
          if (errorData is Map) {
            errorMsg = 'Erro no servidor: ${errorData['detail'] ?? errorData['error'] ?? 'Erro interno'}';
          } else {
            errorMsg = 'Erro interno do servidor. Verifique os logs.';
          }
        } else {
          errorMsg = 'Erro ${e.response?.statusCode}: ${e.message}';
        }
      } else {
        errorMsg = 'Erro de conexão: ${e.message}';
      }
      
      setState(() {
        _error = errorMsg;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading stats: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Painel Administrativo'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove o botão de voltar
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Atualizar',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sair'),
                    content: const Text('Deseja realmente sair do sistema?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                );
                
                if (shouldLogout == true && context.mounted) {
                  final session = SessionScope.of(context);
                  await session.logout();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Sair'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar estatísticas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Métricas principais
            _buildMetricsGrid(),
            const SizedBox(height: 24),

            // Ações rápidas
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Estatísticas de missões
            _buildMissionStats(),
            const SizedBox(height: 24),

            // Atividade recente
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final users = _stats?['total_users'] ?? 0;
    final completedMissions = _stats?['completed_missions'] ?? 0;
    final activeMissions = _stats?['active_missions'] ?? 0;
    final avgLevel = _stats?['avg_user_level'] ?? 0.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _MetricCard(
          title: 'Usuários',
          value: users.toString(),
          icon: Icons.people,
          color: Colors.blue,
          subtitle: 'Total cadastrados',
        ),
        _MetricCard(
          title: 'Missões Completas',
          value: completedMissions.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
          subtitle: 'Todas as faixas',
        ),
        _MetricCard(
          title: 'Missões Ativas',
          value: activeMissions.toString(),
          icon: Icons.assignment,
          color: Colors.orange,
          subtitle: 'Em progresso',
        ),
        _MetricCard(
          title: 'Nível Médio',
          value: avgLevel.toStringAsFixed(1),
          icon: Icons.trending_up,
          color: Colors.purple,
          subtitle: 'Dos usuários',
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ações Rápidas',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.auto_awesome,
                title: 'Gerar Missões com IA',
                subtitle: 'Criar missões personalizadas usando Gemini',
                color: Colors.deepPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAiMissionsPage(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.edit,
                title: 'Gerenciar Missões',
                subtitle: 'Criar, editar e remover missões',
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminMissionsManagementPage(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.category,
                title: 'Gerenciar Categorias',
                subtitle: 'Adicionar e editar categorias padrão',
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCategoriesManagementPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMissionStats() {
    final missionsByDifficulty = _stats?['missions_by_difficulty'] as Map<String, dynamic>?;
    final missionsByType = _stats?['missions_by_type'] as Map<String, dynamic>?;

    if (missionsByDifficulty == null && missionsByType == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estatísticas de Missões',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (missionsByDifficulty != null) ...[
                  _buildStatRow('Fáceis', missionsByDifficulty['EASY'] ?? 0),
                  _buildStatRow('Médias', missionsByDifficulty['MEDIUM'] ?? 0),
                  _buildStatRow('Difíceis', missionsByDifficulty['HARD'] ?? 0),
                  const Divider(height: 24),
                ],
                if (missionsByType != null) ...[
                  _buildStatRow('Onboarding', missionsByType['ONBOARDING'] ?? 0),
                  _buildStatRow('Melhoria TPS', missionsByType['TPS_IMPROVEMENT'] ?? 0),
                  _buildStatRow('Redução RDR', missionsByType['RDR_REDUCTION'] ?? 0),
                  _buildStatRow('Construção ILI', missionsByType['ILI_BUILDING'] ?? 0),
                  _buildStatRow('Avançadas', missionsByType['ADVANCED'] ?? 0),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentActivity = _stats?['recent_activity'] as List<dynamic>?;

    if (recentActivity == null || recentActivity.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Atividade Recente',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentActivity.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = recentActivity[index] as Map<String, dynamic>;
              return ListTile(
                leading: Icon(
                  _getActivityIcon(activity['type'] as String?),
                  color: AppColors.primary,
                ),
                title: Text(activity['description'] as String? ?? ''),
                subtitle: Text(activity['time'] as String? ?? ''),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'mission_completed':
        return Icons.check_circle;
      case 'user_registered':
        return Icons.person_add;
      case 'level_up':
        return Icons.trending_up;
      default:
        return Icons.info;
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
