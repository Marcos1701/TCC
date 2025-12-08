import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/state/session_controller.dart';
import '../../../admin/presentation/admin_panel_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FinanceRepository _repository = FinanceRepository();
  
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackScreenView('profile');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _repository.fetchUserProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadProfile();
    if (mounted) {
      FeedbackService.showSuccess(
        context,
        '✅ Perfil atualizado!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(context),
            tooltip: 'Configurações',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar perfil',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_profile == null) {
      return const Center(
        child: Text('Nenhum dado disponível'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLevelCard(),
          const SizedBox(height: 16),

          _buildQuickStats(),
          const SizedBox(height: 16),

          _buildActionButtons(context),
          const SizedBox(height: 16),

          _buildInfoSection(),
        ],
      ),
    );
  }

  Widget _buildLevelCard() {
    // Lê os dados diretamente do nível raiz (endpoint /user/me/ não usa 'snapshot')
    final level = (_profile!['level'] as int?) ?? 1;
    final xp = (_profile!['experience_points'] as int?) ?? 0;
    final xpForNext = (_profile!['next_level_threshold'] as int?) ?? 150;
    final progress = xpForNext > 0 ? xp / xpForNext : 0.0;

    return Card(
      color: Colors.deepPurple[900]?.withOpacity(0.5),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.deepPurple[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.person,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Nível $level',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '${NumberFormat('#,###', 'pt_BR').format(xp)} pontos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation(Colors.amber),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Faltam ${NumberFormat('#,###', 'pt_BR').format(xpForNext - xp)} pontos para o nível ${level + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    // Lê os dados diretamente do nível raiz (endpoint /user/me/ não usa 'snapshot')
    final level = (_profile!['level'] as int?) ?? 1;
    final xp = (_profile!['experience_points'] as int?) ?? 0;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.emoji_events,
            label: 'Nível',
            value: level.toString(),
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.stars,
            label: 'Pontos',
            value: NumberFormat.compact(locale: 'pt_BR').format(xp),
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final session = SessionScope.of(context);
    final isAdmin = session.session?.user.isAdmin ?? false;
    
    return Column(
      children: [
        if (isAdmin)
          Card(
            color: Colors.deepPurple[900]?.withOpacity(0.7),
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              title: const Text(
                'Painel Administrativo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Gerenciar missões, categorias e usuários',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
              onTap: () => _navigateToAdminPanel(context),
            ),
          ),
        
        if (isAdmin) const SizedBox(height: 8),

        Card(
          color: Colors.grey[900],
          child: ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text(
              'Configurações',
              style: TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            onTap: () => _navigateToSettings(context),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sobre os Pontos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              '💰 Complete desafios para ganhar pontos',
            ),
            _buildInfoItem(
              '📈 Quanto maior o nível, mais recompensas',
            ),
            _buildInfoItem(
              '🏆 Compare seu progresso com amigos',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[300], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _navigateToAdminPanel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPanelPage()),
    );
  }
}
