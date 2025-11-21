import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_widgets.dart';
import '../mixins/admin_page_mixin.dart';
import 'admin_missions_management_page.dart';
import 'admin_categories_management_page.dart';
import 'admin_users_management_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with AdminPageMixin {
  final _apiClient = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _overviewStats;
  Map<String, dynamic>? _userAnalytics;
  Map<String, dynamic>? _systemHealth;
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
      final results = await Future.wait([
        _apiClient.client.get('/api/admin-stats/overview/'),
        _apiClient.client.get('/api/admin-stats/user_analytics/'),
        _apiClient.client.get('/api/admin-stats/system_health/'),
      ]);

      setState(() {
        _overviewStats = _parseResponse(results[0]);
        _userAnalytics = _parseResponse(results[1]);
        _systemHealth = _parseResponse(results[2]);
        _isLoading = false;
      });
    } on DioException catch (e) {
      String errorMsg = 'Erro desconhecido';
      
      if (e.response != null) {
        if (e.response?.statusCode == 403) {
          errorMsg = 'Acesso negado. Privilégios administrativos necessários.';
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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _parseResponse(Response response) {
    if (response.data == null) return {};
    
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else if (response.data is String) {
      return json.decode(response.data.toString()) as Map<String, dynamic>;
    }
    
    throw Exception('Formato de resposta inesperado: ${response.data.runtimeType}');
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
          ? const Center(
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
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildMissionStats(),
            const SizedBox(height: 24),
            _buildTopUsers(),
            const SizedBox(height: 24),
            _buildLevelDistribution(),
            const SizedBox(height: 24),
            _buildSystemHealth(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    int getInt(Map<String, dynamic>? map, String key, [int fallback = 0]) {
      if (map == null) return fallback;
      final value = map[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }
    
    double getDouble(Map<String, dynamic>? map, String key, [double fallback = 0.0]) {
      if (map == null) return fallback;
      final value = map[key];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }
    
    final totalUsers = getInt(_overviewStats, 'total_users');
    final completedMissions = getInt(_overviewStats, 'completed_missions');
    final activeMissions = getInt(_overviewStats, 'active_missions');
    final avgLevel = getDouble(_overviewStats, 'avg_user_level');
    final activeUsers7d = getInt(_userAnalytics, 'active_users_7d');
    final newUsers7d = getInt(_userAnalytics, 'new_users_7d');
    final totalTransactions = getInt(_systemHealth, 'total_transactions');
    final activeGoals = getInt(_systemHealth, 'active_goals');

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        AdminMetricCard(
          title: 'Usuários',
          value: totalUsers.toString(),
          icon: Icons.people,
          color: Colors.blue,
          subtitle: 'Total cadastrados',
        ),
        AdminMetricCard(
          title: 'Ativos (7d)',
          value: activeUsers7d.toString(),
          icon: Icons.trending_up,
          color: Colors.green,
          subtitle: 'Usuários ativos',
        ),
        AdminMetricCard(
          title: 'Completas',
          value: completedMissions.toString(),
          icon: Icons.check_circle,
          color: Colors.purple,
          subtitle: 'Missões finalizadas',
        ),
        AdminMetricCard(
          title: 'Ativas',
          value: activeMissions.toString(),
          icon: Icons.assignment,
          color: Colors.orange,
          subtitle: 'Em progresso',
        ),
        AdminMetricCard(
          title: 'Nível Médio',
          value: avgLevel.toStringAsFixed(1),
          icon: Icons.bar_chart,
          color: AppColors.primary,
          subtitle: 'Dos usuários',
        ),
        AdminMetricCard(
          title: 'Novos (7d)',
          value: newUsers7d.toString(),
          icon: Icons.person_add,
          color: Colors.teal,
          subtitle: 'Cadastros recentes',
        ),
        AdminMetricCard(
          title: 'Transações',
          value: totalTransactions.toString(),
          icon: Icons.attach_money,
          color: Colors.amber,
          subtitle: 'Total registradas',
        ),
        AdminMetricCard(
          title: 'Metas Ativas',
          value: activeGoals.toString(),
          icon: Icons.flag,
          color: Colors.red,
          subtitle: 'Em progresso',
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
                icon: Icons.rocket_launch,
                title: 'Gerenciar Missões',
                subtitle: 'Criar, editar e gerar missões com IA',
                color: AppColors.primary,
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
              Divider(height: 1, color: Colors.grey[800]),
              _ActionTile(
                icon: Icons.manage_accounts,
                title: 'Gerenciar Usuários',
                subtitle: 'Visualizar e gerenciar contas de usuários',
                color: Colors.deepPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminUsersManagementPage(),
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
    final missionsByDifficulty = _overviewStats?['missions_by_difficulty'] as Map<String, dynamic>?;
    final missionsByType = _overviewStats?['missions_by_type'] as Map<String, dynamic>?;

    if (missionsByDifficulty == null && missionsByType == null) {
      return const SizedBox.shrink();
    }
    
    int getInt(Map<String, dynamic>? map, String key) {
      if (map == null) return 0;
      final value = map[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
                  AdminStatRow(label: 'Fácil', value: getInt(missionsByDifficulty, 'easy')),
                  AdminStatRow(label: 'Média', value: getInt(missionsByDifficulty, 'medium')),
                  AdminStatRow(label: 'Difícil', value: getInt(missionsByDifficulty, 'hard')),
                  Divider(height: 24, color: Colors.grey[800]),
                ],
                if (missionsByType != null) ...[
                  AdminStatRow(label: 'Onboarding', value: getInt(missionsByType, 'ONBOARDING')),
                  AdminStatRow(label: 'Melhoria TPS', value: getInt(missionsByType, 'TPS_IMPROVEMENT')),
                  AdminStatRow(label: 'Redução RDR', value: getInt(missionsByType, 'RDR_REDUCTION')),
                  AdminStatRow(label: 'Construção ILI', value: getInt(missionsByType, 'ILI_BUILDING')),
                  AdminStatRow(label: 'Avançadas', value: getInt(missionsByType, 'ADVANCED')),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final recentActivity = _overviewStats?['recent_activity'] as List<dynamic>?;

    if (recentActivity == null || recentActivity.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                title: Text(
                  mission,
                  style: const TextStyle(
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
                    style: const TextStyle(
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

  Widget _buildTopUsers() {
    final topUsers = _userAnalytics?['top_users'] as List<dynamic>?;

    if (topUsers == null || topUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 10 Usuários',
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
            itemCount: topUsers.length > 10 ? 10 : topUsers.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[800]),
            itemBuilder: (context, index) {
              final user = topUsers[index] as Map<String, dynamic>;
              final username = user['username'] as String? ?? 'Desconhecido';
              final level = user['level'] as int? ?? 0;
              final experiencePoints = user['experience_points'] as int? ?? 0;
              final xpToNext = user['xp_to_next_level'] as int? ?? 0;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Nv $level',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '$experiencePoints XP • Faltam $xpToNext XP',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  index < 3 ? Icons.emoji_events : Icons.star,
                  color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey[400] : (index == 2 ? Colors.brown[300] : Colors.grey[700])),
                  size: 24,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLevelDistribution() {
    final levelDistribution = _overviewStats?['level_distribution'] as Map<String, dynamic>?;

    if (levelDistribution == null || levelDistribution.isEmpty) {
      return const SizedBox.shrink();
    }

    // Preparar dados para o gráfico
    final List<MapEntry<String, int>> sortedData = levelDistribution.entries
        .map((e) => MapEntry(e.key, (e.value as num).toInt()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxValue = sortedData.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribuição de Níveis',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxValue + (maxValue * 0.2),
                    minY: 0,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= sortedData.length) return const Text('');
                            return Text(
                              sortedData[value.toInt()].key,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey[800]!,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      sortedData.length,
                      (index) => BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: sortedData[index].value.toDouble(),
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withOpacity(0.5)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemHealth() {
    if (_systemHealth == null) {
      return const SizedBox.shrink();
    }

    int getInt(Map<String, dynamic>? map, String key) {
      if (map == null) return 0;
      final value = map[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final totalTransactions = getInt(_systemHealth, 'total_transactions');
    final transactions7d = getInt(_systemHealth, 'transactions_7d');
    final totalGoals = getInt(_systemHealth, 'total_goals');
    final activeGoals = getInt(_systemHealth, 'active_goals');
    final completedGoals = getInt(_systemHealth, 'completed_goals');
    final categoriesCount = getInt(_systemHealth, 'categories_count');
    final globalCategories = getInt(_systemHealth, 'global_categories');
    final userCategories = getInt(_systemHealth, 'user_categories');
    final totalMissions = getInt(_systemHealth, 'total_missions');
    final aiMissions = getInt(_systemHealth, 'ai_generated_missions');
    final defaultMissions = getInt(_systemHealth, 'default_missions');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saúde do Sistema',
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
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHealthRow('Transações Totais', totalTransactions, Icons.attach_money, Colors.green),
              _buildHealthRow('Transações (7d)', transactions7d, Icons.trending_up, Colors.teal),
              Divider(height: 24, color: Colors.grey[800]),
              _buildHealthRow('Metas Totais', totalGoals, Icons.flag, Colors.orange),
              _buildHealthRow('Metas Ativas', activeGoals, Icons.play_circle, Colors.amber),
              _buildHealthRow('Metas Completas', completedGoals, Icons.check_circle, Colors.green),
              Divider(height: 24, color: Colors.grey[800]),
              _buildHealthRow('Categorias Totais', categoriesCount, Icons.category, Colors.purple),
              _buildHealthRow('Categorias Globais', globalCategories, Icons.public, Colors.blue),
              _buildHealthRow('Categorias Usuários', userCategories, Icons.person, Colors.cyan),
              Divider(height: 24, color: Colors.grey[800]),
              _buildHealthRow('Missões Totais', totalMissions, Icons.assignment, Colors.indigo),
              _buildHealthRow('Missões IA', aiMissions, Icons.auto_awesome, AppColors.primary),
              _buildHealthRow('Missões Padrão', defaultMissions, Icons.star, Colors.amber),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthRow(String label, int value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
        style: const TextStyle(
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