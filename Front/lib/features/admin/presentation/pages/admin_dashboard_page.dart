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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Painel Administrativo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text(
                      'Sair',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Deseja realmente sair do sistema?',
                      style: TextStyle(color: Colors.white70),
                    ),
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
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
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
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.alert.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar estatísticas',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppColors.primary,
      backgroundColor: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
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
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        _MetricCard(
          title: 'Usuários',
          value: users.toString(),
          icon: Icons.people,
          color: Colors.blue,
          subtitle: 'Total cadastrados',
        ),
        _MetricCard(
          title: 'Completas',
          value: completedMissions.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
          subtitle: 'Todas as faixas',
        ),
        _MetricCard(
          title: 'Ativas',
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.auto_awesome,
                title: 'Gerar Missões com IA',
                subtitle: 'Criar missões personalizadas usando Gemini',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAiMissionsPage(),
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey[800]),
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
              Divider(height: 1, color: Colors.grey[800]),
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (missionsByDifficulty != null) ...[
                  _buildStatRow('Fáceis', missionsByDifficulty['EASY'] ?? 0),
                  _buildStatRow('Médias', missionsByDifficulty['MEDIUM'] ?? 0),
                  _buildStatRow('Difíceis', missionsByDifficulty['HARD'] ?? 0),
                  Divider(height: 24, color: Colors.grey[800]),
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 14,
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentActivity.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[800]),
            itemBuilder: (context, index) {
              final activity = recentActivity[index] as Map<String, dynamic>;
              final user = activity['user'] as String? ?? '';
              final mission = activity['mission'] as String? ?? '';
              final xpEarned = activity['xp_earned'] as int? ?? 0;
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                title: Text(
                  mission,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'por $user',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$xpEarned XP',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 24,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[600],
      ),
      onTap: onTap,
    );
  }
}
