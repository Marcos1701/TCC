import 'package:flutter/material.dart';
import '../../data/models/achievement.dart';
import '../../data/services/achievement_service.dart';
import '../../../../core/constants/user_friendly_strings.dart';

class AdminAchievementsPage extends StatefulWidget {
  const AdminAchievementsPage({super.key});

  @override
  State<AdminAchievementsPage> createState() => _AdminAchievementsPageState();
}

class _AdminAchievementsPageState extends State<AdminAchievementsPage> {
  final _achievementService = AchievementService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  List<Achievement> _achievements = [];
  String? _error;
  
  String _filterCategory = 'ALL';
  String _filterTier = 'ALL';
  String _filterOrigin = 'ALL';
  String _filterStatus = 'ALL';
  String _searchQuery = '';
  String _sortBy = 'priority_asc';
  
  bool _isGeneratingAI = false;
  String _selectedAiCategory = 'ALL';
  String _selectedAiTier = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAchievements();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final achievements = await _achievementService.listAchievements();
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

  List<Achievement> get _filteredAndSortedAchievements {
    var filtered = _achievements.where((achievement) {
      if (_filterCategory != 'ALL' && achievement.category != _filterCategory) {
        return false;
      }

      if (_filterTier != 'ALL' && achievement.tier != _filterTier) {
        return false;
      }

      if (_filterOrigin == 'AI' && !achievement.isAiGenerated) return false;
      if (_filterOrigin == 'MANUAL' && achievement.isAiGenerated) return false;

      if (_filterStatus == 'ACTIVE' && !achievement.isActive) return false;
      if (_filterStatus == 'INACTIVE' && achievement.isActive) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = achievement.title.toLowerCase();
        final description = achievement.description.toLowerCase();
        if (!title.contains(query) && !description.contains(query)) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'priority_asc':
          return a.priority.compareTo(b.priority);
        case 'points_desc':
          return b.xpReward.compareTo(a.xpReward);
        case 'points_asc':
          return a.xpReward.compareTo(b.xpReward);
        case 'date_desc':
          return b.createdAt.compareTo(a.createdAt);
        case 'date_asc':
          return a.createdAt.compareTo(b.createdAt);
        default:
          return 0;
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Conquistas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showAiGenerationDialog,
            tooltip: 'Gerar com IA',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: 'Criar Conquista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Estatísticas
          _buildStatsBar(),
          
          // Filtros e busca
          _buildFiltersBar(),
          
          // Lista de conquistas
          Expanded(child: _buildAchievementsList()),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _achievements.length;
    final active = _achievements.where((a) => a.isActive).length;
    final aiGenerated = _achievements.where((a) => a.isAiGenerated).length;
    final manual = total - aiGenerated;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.emoji_events,
            label: 'Total',
            value: total.toString(),
            color: Colors.blue,
          ),
          _buildStatItem(
            icon: Icons.check_circle,
            label: 'Ativas',
            value: active.toString(),
            color: Colors.green,
          ),
          _buildStatItem(
            icon: Icons.auto_awesome,
            label: 'IA',
            value: aiGenerated.toString(),
            color: Colors.purple,
          ),
          _buildStatItem(
            icon: Icons.edit,
            label: 'Manual',
            value: manual.toString(),
            color: Colors.orange,
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
        Icon(icon, color: color, size: 24),
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
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Busca
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar conquistas...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Filtros em chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Categoria
                PopupMenuButton<String>(
                  child: Chip(
                    avatar: const Icon(Icons.category, size: 18),
                    label: Text(_filterCategory == 'ALL' ? 'Categoria' : _getCategoryName(_filterCategory)),
                  ),
                  onSelected: (value) => setState(() => _filterCategory = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'ALL', child: Text('Todas')),
                    const PopupMenuItem(value: 'FINANCIAL', child: Text('Financeiro')),
                    const PopupMenuItem(value: 'SOCIAL', child: Text('Social')),
                    const PopupMenuItem(value: 'MISSION', child: Text(UxStrings.challenges)),
                    const PopupMenuItem(value: 'STREAK', child: Text('Sequência')),
                    const PopupMenuItem(value: 'GENERAL', child: Text('Geral')),
                  ],
                ),
                const SizedBox(width: 8),
                
                // Tier
                PopupMenuButton<String>(
                  child: Chip(
                    avatar: const Icon(Icons.military_tech, size: 18),
                    label: Text(_filterTier == 'ALL' ? 'Tier' : _getTierName(_filterTier)),
                  ),
                  onSelected: (value) => setState(() => _filterTier = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'ALL', child: Text('Todos')),
                    const PopupMenuItem(value: 'BEGINNER', child: Text('Iniciante')),
                    const PopupMenuItem(value: 'INTERMEDIATE', child: Text('Intermediário')),
                    const PopupMenuItem(value: 'ADVANCED', child: Text('Avançado')),
                  ],
                ),
                const SizedBox(width: 8),
                
                // Origem
                PopupMenuButton<String>(
                  child: Chip(
                    avatar: const Icon(Icons.source, size: 18),
                    label: Text(_filterOrigin == 'ALL' ? 'Origem' : _filterOrigin),
                  ),
                  onSelected: (value) => setState(() => _filterOrigin = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'ALL', child: Text('Todas')),
                    const PopupMenuItem(value: 'AI', child: Text('IA')),
                    const PopupMenuItem(value: 'MANUAL', child: Text('Manual')),
                  ],
                ),
                const SizedBox(width: 8),
                
                // Status
                PopupMenuButton<String>(
                  child: Chip(
                    avatar: const Icon(Icons.toggle_on, size: 18),
                    label: Text(_filterStatus == 'ALL' ? 'Status' : _filterStatus == 'ACTIVE' ? 'Ativas' : 'Inativas'),
                  ),
                  onSelected: (value) => setState(() => _filterStatus = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'ALL', child: Text('Todas')),
                    const PopupMenuItem(value: 'ACTIVE', child: Text('Ativas')),
                    const PopupMenuItem(value: 'INACTIVE', child: Text('Inativas')),
                  ],
                ),
                const SizedBox(width: 8),
                
                // Ordenação
                PopupMenuButton<String>(
                  child: const Chip(
                    avatar: Icon(Icons.sort, size: 18),
                    label: Text('Ordenar'),
                  ),
                  onSelected: (value) => setState(() => _sortBy = value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'priority_asc', child: Text('Prioridade')),
                    const PopupMenuItem(value: 'points_desc', child: Text('${UxStrings.points} (Maior)')),
                    const PopupMenuItem(value: 'points_asc', child: Text('${UxStrings.points} (Menor)')),
                    const PopupMenuItem(value: 'date_desc', child: Text('Mais Recente')),
                    const PopupMenuItem(value: 'date_asc', child: Text('Mais Antiga')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList() {
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
            const Text('Erro ao carregar conquistas'),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
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

    final filtered = _filteredAndSortedAchievements;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Nenhuma conquista encontrada'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _filterCategory = 'ALL';
                  _filterTier = 'ALL';
                  _filterOrigin = 'ALL';
                  _filterStatus = 'ALL';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpar Filtros'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAchievements,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final achievement = filtered[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: achievement.isActive
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                child: Text(achievement.icon, style: const TextStyle(fontSize: 24)),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(achievement.title)),
                  if (achievement.isAiGenerated)
                    const Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(achievement.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      Chip(
                        label: Text(achievement.categoryName, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        label: Text(achievement.tierName, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        label: Text('+${achievement.xpReward} ${UxStrings.points}', style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(achievement.isActive ? Icons.pause : Icons.play_arrow),
                        const SizedBox(width: 8),
                        Text(achievement.isActive ? 'Desativar' : 'Ativar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Excluir', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditDialog(achievement);
                      break;
                    case 'toggle':
                      _toggleAchievementStatus(achievement);
                      break;
                    case 'delete':
                      _confirmDelete(achievement);
                      break;
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAiGenerationDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple),
              SizedBox(width: 8),
              Text('Gerar Conquistas com IA'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Use o Google Gemini para gerar conquistas contextualizadas automaticamente.'),
              const SizedBox(height: 16),
              
              // Categoria
              DropdownButtonFormField<String>(
                value: _selectedAiCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Todas (30 conquistas)')),
                  DropdownMenuItem(value: 'FINANCIAL', child: Text('Financeiro')),
                  DropdownMenuItem(value: 'SOCIAL', child: Text('Social')),
                  DropdownMenuItem(value: 'MISSION', child: Text(UxStrings.challenges)),
                  DropdownMenuItem(value: 'STREAK', child: Text('Sequência')),
                  DropdownMenuItem(value: 'GENERAL', child: Text('Geral')),
                ],
                onChanged: (value) => setState(() => _selectedAiCategory = value!),
              ),
              const SizedBox(height: 12),
              
              // Tier
              DropdownButtonFormField<String>(
                value: _selectedAiTier,
                decoration: const InputDecoration(
                  labelText: 'Dificuldade',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Todas (30 conquistas)')),
                  DropdownMenuItem(value: 'BEGINNER', child: Text('Iniciante (10 conquistas)')),
                  DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediário (10 conquistas)')),
                  DropdownMenuItem(value: 'ADVANCED', child: Text('Avançado (10 conquistas)')),
                ],
                onChanged: (value) => setState(() => _selectedAiTier = value!),
              ),
              const SizedBox(height: 16),
              
              if (_isGeneratingAI)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isGeneratingAI ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: _isGeneratingAI ? null : () => _generateWithAi(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Gerar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateWithAi(BuildContext dialogContext) async {
    setState(() => _isGeneratingAI = true);

    try {
      final result = await _achievementService.generateAiAchievements(
        category: _selectedAiCategory,
        tier: _selectedAiTier,
      );

      if (!mounted) return;
      if (!dialogContext.mounted) return;
      
      Navigator.pop(dialogContext);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['created']} conquistas criadas! '
            '(${result['total']} geradas, ${result['cached'] ? 'do cache' : 'novas'})',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      await _loadAchievements();
    } catch (e) {
      if (!mounted) return;
      if (!dialogContext.mounted) return;
      
      Navigator.pop(dialogContext);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar conquistas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAI = false);
      }
    }
  }

  void _showCreateDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Criação manual em desenvolvimento')),
    );
  }

  void _showEditDialog(Achievement achievement) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edição em desenvolvimento')),
    );
  }

  Future<void> _toggleAchievementStatus(Achievement achievement) async {
    try {
      await _achievementService.updateAchievement(
        achievementId: achievement.id,
        isActive: !achievement.isActive,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(achievement.isActive ? 'Conquista desativada' : 'Conquista ativada'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadAchievements();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Achievement achievement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir a conquista "${achievement.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _achievementService.deleteAchievement(achievement.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conquista excluída'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadAchievements();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
