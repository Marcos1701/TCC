import 'package:flutter/material.dart';
import '../../data/models/achievement.dart';
import '../../data/services/achievement_service.dart';
import '../widgets/achievement_card.dart';
import '../widgets/achievement_notification.dart';
import '../../../../core/constants/user_friendly_strings.dart';

/// Página de conquistas do usuário
/// 
/// Mostra:
/// - Tab "Desbloqueadas": Conquistas já obtidas
/// - Tab "Em Progresso": Conquistas não desbloqueadas com progresso
/// - Filtros por categoria e tier
/// - Estatísticas: total desbloqueadas, XP ganho, etc.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> with SingleTickerProviderStateMixin {
  final _achievementService = AchievementService();
  
  List<UserAchievement> _achievements = [];
  bool _isLoading = true;
  String? _error;
  
  late TabController _tabController;
  
  // Filtros
  String? _selectedCategory;
  String? _selectedTier;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final achievements = await _achievementService.getMyAchievements();
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<UserAchievement> get _unlockedAchievements {
    return _filteredAchievements.where((a) => a.isUnlocked).toList();
  }

  List<UserAchievement> get _lockedAchievements {
    return _filteredAchievements.where((a) => !a.isUnlocked).toList();
  }

  List<UserAchievement> get _filteredAchievements {
    var filtered = _achievements;
    
    if (_selectedCategory != null) {
      filtered = filtered.where((a) => a.achievement.category == _selectedCategory).toList();
    }
    
    if (_selectedTier != null) {
      filtered = filtered.where((a) => a.achievement.tier == _selectedTier).toList();
    }
    
    return filtered;
  }

  int get _totalXpEarned {
    return _unlockedAchievements.fold(
      0,
      (sum, achievement) => sum + achievement.achievement.xpReward,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conquistas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.emoji_events),
              text: 'Desbloqueadas (${_unlockedAchievements.length})',
            ),
            Tab(
              icon: const Icon(Icons.lock_clock),
              text: 'Em Progresso (${_lockedAchievements.length})',
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar conquistas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAchievements,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    if (_achievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma conquista disponível',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Continue usando o app para desbloquear conquistas!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStatsBar(),
        
        if (_selectedCategory != null || _selectedTier != null)
          _buildActiveFilters(),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAchievementsList(_unlockedAchievements, isEmpty: 'Nenhuma conquista desbloqueada ainda'),
              _buildAchievementsList(_lockedAchievements, isEmpty: 'Todas as conquistas desbloqueadas.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.emoji_events,
            label: 'Desbloqueadas',
            value: '${_unlockedAchievements.length}/${_achievements.length}',
            color: Colors.amber,
          ),
          _buildStatItem(
            icon: Icons.stars,
            label: 'XP Ganho',
            value: '$_totalXpEarned',
            color: Colors.blue,
          ),
          _buildStatItem(
            icon: Icons.trending_up,
            label: 'Progresso',
            value: '${(_unlockedAchievements.length / _achievements.length * 100).toStringAsFixed(0)}%',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          if (_selectedCategory != null)
            Chip(
              label: Text(_getCategoryName(_selectedCategory!)),
              onDeleted: () => setState(() => _selectedCategory = null),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (_selectedTier != null)
            Chip(
              label: Text(_getTierName(_selectedTier!)),
              onDeleted: () => setState(() => _selectedTier = null),
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList(List<UserAchievement> achievements, {required String isEmpty}) {
    if (achievements.isEmpty) {
      return Center(
        child: Text(
          isEmpty,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAchievements,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AchievementCard(
              userAchievement: achievement,
              onTap: () => _showAchievementDetails(achievement),
            ),
          );
        },
      ),
    );
  }

  void _showAchievementDetails(UserAchievement userAchievement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final achievement = userAchievement.achievement;
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Ícone grande
              Center(
                child: Text(achievement.icon, style: const TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 16),
              
              // Título
              Text(
                achievement.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(label: Text(achievement.categoryName)),
                  const SizedBox(width: 8),
                  Chip(label: Text(achievement.tierName)),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.stars, size: 16),
                    label: Text('+${achievement.xpReward} XP'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Descrição
              Text(
                achievement.description,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Critério
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Objetivo',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement.criteria.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Progresso
              if (!userAchievement.isUnlocked)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progresso',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: userAchievement.progressPercentage / 100,
                          minHeight: 12,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userAchievement.progressDescription,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Status desbloqueado
              if (userAchievement.isUnlocked && userAchievement.unlockedAt != null)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Conquista Desbloqueada!',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                'Em ${userAchievement.unlockedAt!.day}/${userAchievement.unlockedAt!.month}/${userAchievement.unlockedAt!.year}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Botão de teste para desbloquear (apenas para conquistas não desbloqueadas)
              if (!userAchievement.isUnlocked)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _unlockAchievement(achievement.id);
                    },
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Desbloquear (Teste)'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Desbloqueia uma conquista manualmente (para teste)
  /// Exibe a notificação animada após o desbloqueio
  Future<void> _unlockAchievement(int achievementId) async {
    try {
      final result = await _achievementService.unlockAchievement(achievementId);
      
      if (result['status'] == 'unlocked') {
        // Encontrar a conquista desbloqueada
        final userAchievement = _achievements.firstWhere(
          (a) => a.achievement.id == achievementId,
        );
        
        // Exibir notificação de desbloqueio
        if (mounted) {
          AchievementNotification.show(
            context,
            achievement: userAchievement.achievement,
            pointsAwarded: result['xp_awarded'] ?? userAchievement.achievement.xpReward,
          );
        }
        
        // Recarregar lista de conquistas
        await _loadAchievements();
        
        // Mostrar snackbar com mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conquista desbloqueada! +${result['xp_awarded']} XP'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (result['status'] == 'already_unlocked') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esta conquista já foi desbloqueada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desbloquear conquista: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categoria',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = null);
                    Navigator.pop(context);
                  },
                ),
                ...['FINANCIAL', 'SOCIAL', 'MISSION', 'STREAK', 'GENERAL'].map((category) {
                  return FilterChip(
                    label: Text(_getCategoryName(category)),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = selected ? category : null);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Dificuldade',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: _selectedTier == null,
                  onSelected: (selected) {
                    setState(() => _selectedTier = null);
                    Navigator.pop(context);
                  },
                ),
                ...['BEGINNER', 'INTERMEDIATE', 'ADVANCED'].map((tier) {
                  return FilterChip(
                    label: Text(_getTierName(tier)),
                    selected: _selectedTier == tier,
                    onSelected: (selected) {
                      setState(() => _selectedTier = selected ? tier : null);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _selectedTier = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Limpar Filtros'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String category) {
    final names = {
      'FINANCIAL': 'Financeiro',
      'SOCIAL': 'Social',
      'MISSION': UxStrings.challenges,
      'STREAK': 'Sequência',
      'GENERAL': 'Geral',
    };
    return names[category] ?? category;
  }

  String _getTierName(String tier) {
    const names = {
      'BEGINNER': 'Iniciante',
      'INTERMEDIATE': 'Intermediário',
      'ADVANCED': 'Avançado',
    };
    return names[tier] ?? tier;
  }
}
