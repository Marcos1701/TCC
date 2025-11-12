import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/admin_user_service.dart';
import 'admin_user_details_page.dart';

/// Página de listagem e gerenciamento de usuários (Admin)
/// 
/// Recursos:
/// - Lista paginada de usuários
/// - Filtros: tier, status, busca
/// - Ordenação por data, level, XP
/// - Navegação para detalhes
class AdminUsersManagementPage extends StatefulWidget {
  const AdminUsersManagementPage({super.key});

  @override
  State<AdminUsersManagementPage> createState() => _AdminUsersManagementPageState();
}

class _AdminUsersManagementPageState extends State<AdminUsersManagementPage> {
  final _service = AdminUserService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  
  List<Map<String, dynamic>> _users = [];
  int _totalUsers = 0;
  int _currentPage = 1;
  bool _hasNext = false;
  bool _hasPrevious = false;

  // Filtros
  String? _selectedTier;
  bool? _selectedStatus;
  String _ordering = '-date_joined';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.listUsers(
        tier: _selectedTier,
        isActive: _selectedStatus,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        ordering: _ordering,
        page: _currentPage,
      );

      setState(() {
        _totalUsers = result['count'] as int;
        _hasNext = result['next'] != null;
        _hasPrevious = result['previous'] != null;
        _users = (result['results'] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _nextPage() {
    if (_hasNext) {
      setState(() => _currentPage++);
      _loadUsers();
    }
  }

  void _previousPage() {
    if (_hasPrevious) {
      setState(() => _currentPage--);
      _loadUsers();
    }
  }

  void _applyFilters() {
    setState(() => _currentPage = 1);
    _loadUsers();
  }

  void _clearFilters() {
    setState(() {
      _selectedTier = null;
      _selectedStatus = null;
      _searchController.clear();
      _ordering = '-date_joined';
      _currentPage = 1;
    });
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Gestão de Usuários',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildUserList(),
          ),
          if (!_isLoading && _users.isNotEmpty) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        children: [
          // Busca
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por username ou email...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),

          // Filtros em linha
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Tier
                _buildChipFilter(
                  label: 'Iniciante',
                  icon: Icons.star_outline,
                  isSelected: _selectedTier == 'BEGINNER',
                  onTap: () {
                    setState(() => _selectedTier = _selectedTier == 'BEGINNER' ? null : 'BEGINNER');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildChipFilter(
                  label: 'Intermediário',
                  icon: Icons.star_half,
                  isSelected: _selectedTier == 'INTERMEDIATE',
                  onTap: () {
                    setState(() => _selectedTier = _selectedTier == 'INTERMEDIATE' ? null : 'INTERMEDIATE');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildChipFilter(
                  label: 'Avançado',
                  icon: Icons.star,
                  isSelected: _selectedTier == 'ADVANCED',
                  onTap: () {
                    setState(() => _selectedTier = _selectedTier == 'ADVANCED' ? null : 'ADVANCED');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 16),

                // Status
                _buildChipFilter(
                  label: 'Ativos',
                  icon: Icons.check_circle_outline,
                  isSelected: _selectedStatus == true,
                  color: Colors.green,
                  onTap: () {
                    setState(() => _selectedStatus = _selectedStatus == true ? null : true);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildChipFilter(
                  label: 'Inativos',
                  icon: Icons.block,
                  isSelected: _selectedStatus == false,
                  color: Colors.red,
                  onTap: () {
                    setState(() => _selectedStatus = _selectedStatus == false ? null : false);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 16),

                // Limpar filtros
                if (_selectedTier != null || _selectedStatus != null || _searchController.text.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Limpar'),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Ordenação
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Ordenar: ', style: TextStyle(color: AppColors.textSecondary)),
                _buildSortChip('Mais recentes', '-date_joined'),
                _buildSortChip('Mais antigos', 'date_joined'),
                _buildSortChip('Maior nível', '-level'),
                _buildSortChip('Maior XP', '-experience_points'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFilter({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : (color ?? AppColors.primary),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color ?? AppColors.primary,
      checkmarkColor: Colors.white,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _ordering == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _ordering = value);
          _applyFilters();
        },
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.background,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStats() {
    if (_isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.people, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text(
            '$_totalUsers usuários',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_selectedTier != null || _selectedStatus != null) ...[
            const SizedBox(width: 8),
            Text(
              '(filtrados)',
              style: TextStyle(
                color: AppColors.primary.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Nenhum usuário encontrado',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpar filtros'),
              onPressed: _clearFilters,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _users[index];
        return _UserCard(
          user: user,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminUserDetailsPage(userId: user['id'] as int),
            ),
          ).then((_) => _loadUsers()), // Recarregar ao voltar
        );
      },
    );
  }

  Widget _buildPagination() {
    final startItem = (_currentPage - 1) * 20 + 1;
    final endItem = startItem + _users.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $startItem-$endItem de $_totalUsers',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _hasPrevious ? _previousPage : null,
                color: _hasPrevious ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
              ),
              Text(
                'Página $_currentPage',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _hasNext ? _nextPage : null,
                color: _hasNext ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              onPressed: _loadUsers,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] as bool;
    final level = user['level'] as int;
    final xp = user['experience_points'] as int;
    final tier = user['tier'] as String;
    final transactionCount = user['transaction_count'] as int;
    final dateJoined = DateTime.parse(user['date_joined'] as String);
    final lastLogin = user['last_login'] != null
        ? DateTime.parse(user['last_login'] as String)
        : null;

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getTierColor(tier).withOpacity(0.2),
                    child: Text(
                      (user['username'] as String).substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: _getTierColor(tier),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user['username'] as String,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(isActive),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['email'] as String,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Tier badge
                  _buildTierBadge(tier),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Estatísticas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat(Icons.military_tech, 'Nível $level', AppColors.highlight),
                  _buildStat(Icons.stars, '$xp XP', AppColors.primary),
                  _buildStat(Icons.receipt_long, '$transactionCount trans.', AppColors.secondary),
                ],
              ),

              const SizedBox(height: 12),

              // Datas
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Desde ${DateFormat('dd/MM/yyyy').format(dateJoined)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  if (lastLogin != null) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.login, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Último acesso: ${_formatLastLogin(lastLogin)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        isActive ? 'ATIVO' : 'INATIVO',
        style: TextStyle(
          color: isActive ? Colors.green : Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    String label;
    IconData icon;
    switch (tier) {
      case 'BEGINNER':
        label = 'Iniciante';
        icon = Icons.star_outline;
        break;
      case 'INTERMEDIATE':
        label = 'Intermediário';
        icon = Icons.star_half;
        break;
      case 'ADVANCED':
        label = 'Avançado';
        icon = Icons.star;
        break;
      default:
        label = tier;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getTierColor(tier).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _getTierColor(tier)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: _getTierColor(tier),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'BEGINNER':
        return Colors.blue;
      case 'INTERMEDIATE':
        return Colors.purple;
      case 'ADVANCED':
        return AppColors.highlight;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatLastLogin(DateTime lastLogin) {
    final now = DateTime.now();
    final difference = now.difference(lastLogin);

    if (difference.inDays > 0) {
      return '${difference.inDays}d atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h atrás';
    } else {
      return '${difference.inMinutes}min atrás';
    }
  }
}
