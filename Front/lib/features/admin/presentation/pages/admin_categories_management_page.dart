import 'package:flutter/material.dart';
import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

/// Página para gerenciar categorias globais
class AdminCategoriesManagementPage extends StatefulWidget {
  const AdminCategoriesManagementPage({super.key});

  @override
  State<AdminCategoriesManagementPage> createState() =>
      _AdminCategoriesManagementPageState();
}

class _AdminCategoriesManagementPageState
    extends State<AdminCategoriesManagementPage> {
  final _apiClient = ApiClient();
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  String? _error;
  String _filterType = 'ALL';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Buscar apenas categorias globais (sem user)
      final response = await _apiClient.client.get(
        '/api/categories/',
      );

      if (response.data != null) {
        List<dynamic> dataList;
        
        if (response.data is List) {
          dataList = response.data as List;
        } else if (response.data is String) {
          dataList = json.decode(response.data.toString()) as List;
        } else if (response.data is Map && response.data['results'] != null) {
          dataList = response.data['results'] as List;
        } else {
          dataList = [];
        }
        
        final allCategories = dataList.cast<Map<String, dynamic>>();
        
        // Filtrar apenas categorias globais (is_user_created = false)
        // Nota: Se o campo não existir, considera como global (false)
        setState(() {
          _categories = allCategories
              .where((cat) => (cat['is_user_created'] ?? false) == false)
              .toList();
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

  List<Map<String, dynamic>> get _filteredCategories {
    var filtered = _categories;
    
    // Filtro por tipo
    if (_filterType != 'ALL') {
      filtered = filtered.where((cat) => cat['type'] == _filterType).toList();
    }
    
    // Filtro por busca
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((cat) {
        final name = (cat['name'] as String? ?? '').toLowerCase();
        final group = (cat['group'] as String? ?? '').toLowerCase();
        final groupLabel = _getGroupLabel(cat['group'] as String? ?? '').toLowerCase();
        return name.contains(query) || 
               group.contains(query) || 
               groupLabel.contains(query);
      }).toList();
    }
    
    return filtered;
  }
  
  String _getGroupLabel(String group) {
    switch (group) {
      case 'REGULAR_INCOME':
        return 'Renda principal';
      case 'EXTRA_INCOME':
        return 'Renda extra';
      case 'SAVINGS':
        return 'Poupança / Reserva';
      case 'INVESTMENT':
        return 'Investimentos';
      case 'ESSENTIAL_EXPENSE':
        return 'Despesas essenciais';
      case 'LIFESTYLE_EXPENSE':
        return 'Estilo de vida';
      case 'GOAL':
        return 'Metas e sonhos';
      case 'OTHER':
        return 'Outros';
      default:
        return group;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Gerenciar Categorias',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Atualizar',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategoryDialog(),
            tooltip: 'Nova Categoria',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _error != null
                    ? _buildError()
                    : _buildCategoriesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey[500], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar categorias...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  // Rebuild para atualizar a lista filtrada
                });
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
              },
              tooltip: 'Limpar busca',
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
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.filter_list,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Filtrar por tipo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            selected: {_filterType},
            onSelectionChanged: (Set<String> selected) {
              setState(() {
                _filterType = selected.first;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return const Color(0xFF2A2A2A);
                },
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.grey[400]!;
                },
              ),
              side: WidgetStateProperty.resolveWith<BorderSide>(
                (Set<WidgetState> states) {
                  return BorderSide(
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : Colors.grey[700]!,
                    width: 1,
                  );
                },
              ),
            ),
            segments: const [
              ButtonSegment(
                value: 'ALL',
                label: Text('Todas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                icon: Icon(Icons.category, size: 18),
              ),
              ButtonSegment(
                value: 'INCOME',
                label: Text('Receitas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                icon: Icon(Icons.arrow_downward, size: 18),
              ),
              ButtonSegment(
                value: 'EXPENSE',
                label: Text('Despesas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                icon: Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey[800]),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_filteredCategories.length} ${_filteredCategories.length == 1 ? 'categoria encontrada' : 'categorias encontradas'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_searchController.text.isNotEmpty || _filterType != 'ALL') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total: ${_categories.length} ${_categories.length == 1 ? 'categoria global' : 'categorias globais'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
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
              'Erro ao carregar categorias',
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
              onPressed: _loadCategories,
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

  Widget _buildCategoriesList() {
    if (_filteredCategories.isEmpty) {
      final isSearching = _searchController.text.isNotEmpty;
      final isFiltering = _filterType != 'ALL';
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSearching ? Icons.search_off : Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSearching 
                    ? 'Nenhum resultado encontrado'
                    : 'Nenhuma categoria encontrada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? 'Tente ajustar os termos da busca'
                    : isFiltering
                        ? 'Não há categorias globais do tipo selecionado'
                        : 'Não há categorias globais no sistema',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (isSearching || isFiltering) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _filterType = 'ALL';
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpar filtros'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Agrupar por tipo
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final cat in _filteredCategories) {
      final type = cat['type'] as String;
      byType.putIfAbsent(type, () => []).add(cat);
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: AppColors.primary,
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          if (_filterType == 'ALL' || _filterType == 'INCOME')
            _buildCategorySection('INCOME', 'Receitas', byType['INCOME'] ?? []),
          if (_filterType == 'ALL' || _filterType == 'EXPENSE')
            _buildCategorySection('EXPENSE', 'Despesas', byType['EXPENSE'] ?? []),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String type,
    String title,
    List<Map<String, dynamic>> categories,
  ) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  size: 20,
                  color: _getTypeColor(type),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getTypeColor(type).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${categories.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getTypeColor(type),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Column(
            children: [
              for (var i = 0; i < categories.length; i++) ...[
                _CategoryTile(
                  category: categories[i],
                  onTap: () => _showCategoryDetailsDialog(categories[i]),
                  onEdit: () => _showEditCategoryDialog(categories[i]),
                  onDelete: () => _confirmDeleteCategory(categories[i]),
                ),
                if (i < categories.length - 1)
                  Divider(
                    height: 1,
                    color: Colors.grey[850],
                    indent: 76,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'INCOME':
        return Icons.arrow_downward;
      case 'EXPENSE':
        return Icons.arrow_upward;
      default:
        return Icons.category;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'INCOME':
        return AppColors.success;
      case 'EXPENSE':
        return AppColors.alert;
      default:
        return Colors.grey;
    }
  }
  
  // ==================== CRUD METHODS ====================
  
  Future<void> _showAddCategoryDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        onSave: (categoryData) async {
          await _createCategory(categoryData);
        },
      ),
    );
  }
  
  Future<void> _showEditCategoryDialog(Map<String, dynamic> category) async {
    await showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        category: category,
        onSave: (categoryData) async {
          await _updateCategory(category['id'], categoryData);
        },
      ),
    );
  }
  
  Future<void> _showCategoryDetailsDialog(Map<String, dynamic> category) async {
    await showDialog(
      context: context,
      builder: (context) => _CategoryDetailsDialog(
        category: category,
        onEdit: () {
          Navigator.pop(context);
          _showEditCategoryDialog(category);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDeleteCategory(category);
        },
      ),
    );
  }
  
  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Excluir Categoria',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tem certeza que deseja excluir a categoria "${category['name']}"?\n\nEsta ação não pode ser desfeita.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alert,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteCategory(category['id']);
    }
  }
  
  Future<void> _createCategory(Map<String, dynamic> categoryData) async {
    try {
      final response = await _apiClient.client.post(
        '/api/categories/',
        data: categoryData,
      );
      
      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoria criada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erro ao criar categoria';
        
        // Tentar extrair mensagem de erro específica
        if (e.toString().contains('DioException')) {
          final match = RegExp(r'"message":"([^"]+)"').firstMatch(e.toString());
          if (match != null) {
            errorMessage = match.group(1) ?? errorMessage;
          } else if (e.toString().contains('400')) {
            errorMessage = 'Dados inválidos. Verifique os campos e tente novamente.';
          } else if (e.toString().contains('403')) {
            errorMessage = 'Você não tem permissão para criar esta categoria.';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.alert,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  Future<void> _updateCategory(dynamic id, Map<String, dynamic> categoryData) async {
    try {
      final response = await _apiClient.client.put(
        '/api/categories/$id/',
        data: categoryData,
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoria atualizada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erro ao atualizar categoria';
        
        // Tentar extrair mensagem de erro específica
        if (e.toString().contains('DioException')) {
          if (e.toString().contains('400')) {
            errorMessage = 'Dados inválidos. Verifique os campos e tente novamente.';
          } else if (e.toString().contains('403')) {
            errorMessage = 'Você não tem permissão para editar esta categoria.';
          } else if (e.toString().contains('404')) {
            errorMessage = 'Categoria não encontrada.';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.alert,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  Future<void> _deleteCategory(dynamic id) async {
    try {
      final response = await _apiClient.client.delete(
        '/api/categories/$id/',
      );
      
      if (response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoria excluída com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erro ao excluir categoria';
        
        // Tentar extrair mensagem de erro específica
        if (e.toString().contains('DioException')) {
          if (e.toString().contains('transação')) {
            errorMessage = 'Esta categoria possui transações vinculadas. Reatribua-as antes de excluir.';
          } else if (e.toString().contains('meta')) {
            errorMessage = 'Esta categoria possui metas vinculadas. Reatribua-as antes de excluir.';
          } else if (e.toString().contains('403')) {
            errorMessage = 'Você não tem permissão para excluir esta categoria.';
          } else if (e.toString().contains('404')) {
            errorMessage = 'Categoria não encontrada.';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.alert,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

// ==================== DIALOGS ====================

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    this.category,
    required this.onSave,
  });

  final Map<String, dynamic>? category;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedType;
  late String _selectedGroup;
  late String _selectedColor;
  bool _isSystemDefault = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categoryColors = [
    {'color': '#FF5252', 'name': 'Vermelho'},
    {'color': '#FF4081', 'name': 'Rosa'},
    {'color': '#E040FB', 'name': 'Roxo'},
    {'color': '#7C4DFF', 'name': 'Violeta'},
    {'color': '#536DFE', 'name': 'Índigo'},
    {'color': '#448AFF', 'name': 'Azul'},
    {'color': '#40C4FF', 'name': 'Azul Claro'},
    {'color': '#18FFFF', 'name': 'Ciano'},
    {'color': '#64FFDA', 'name': 'Turquesa'},
    {'color': '#69F0AE', 'name': 'Verde Claro'},
    {'color': '#B2FF59', 'name': 'Lima'},
    {'color': '#EEFF41', 'name': 'Amarelo'},
    {'color': '#FFD740', 'name': 'Âmbar'},
    {'color': '#FFAB40', 'name': 'Laranja'},
    {'color': '#FF6E40', 'name': 'Laranja Escuro'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.category?['name'] ?? '',
    );
    _selectedType = widget.category?['type'] ?? 'EXPENSE';
    _selectedGroup = widget.category?['group'] ?? 'OTHER';
    _selectedColor = widget.category?['color'] ?? '#448AFF';
    _isSystemDefault = widget.category?['is_system_default'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        isEditing ? 'Editar Categoria' : 'Nova Categoria',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nome da Categoria',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  if (value.length > 100) {
                    return 'Nome muito longo (máx. 100 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Tipo
              Text(
                'Tipo',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                selected: {_selectedType},
                onSelectionChanged: (Set<String> selected) {
                  setState(() {
                    _selectedType = selected.first;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : const Color(0xFF2A2A2A),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'INCOME',
                    label: Text('Receita'),
                    icon: Icon(Icons.arrow_downward, size: 16),
                  ),
                  ButtonSegment(
                    value: 'EXPENSE',
                    label: Text('Despesa'),
                    icon: Icon(Icons.arrow_upward, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Grupo
              DropdownButtonFormField<String>(
                value: _selectedGroup,
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Grupo',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
                items: _getGroupOptions()
                    .map((group) => DropdownMenuItem(
                          value: group['value'],
                          child: Text(group['label']!),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGroup = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Cor
              Text(
                'Cor',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoryColors.map((colorData) {
                  final color = Color(int.parse(
                    colorData['color'].replaceFirst('#', '0xFF'),
                  ));
                  final isSelected = _selectedColor == colorData['color'];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorData['color'];
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Categoria padrão do sistema
              CheckboxListTile(
                value: _isSystemDefault,
                onChanged: (value) {
                  setState(() {
                    _isSystemDefault = value ?? false;
                  });
                },
                title: Text(
                  'Categoria padrão do sistema',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                subtitle: Text(
                  'Será criada automaticamente para novos usuários',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }

  List<Map<String, String>> _getGroupOptions() {
    if (_selectedType == 'INCOME') {
      return [
        {'value': 'REGULAR_INCOME', 'label': 'Renda principal'},
        {'value': 'EXTRA_INCOME', 'label': 'Renda extra'},
        {'value': 'SAVINGS', 'label': 'Poupança / Reserva'},
        {'value': 'INVESTMENT', 'label': 'Investimentos'},
        {'value': 'OTHER', 'label': 'Outros'},
      ];
    } else {
      return [
        {'value': 'ESSENTIAL_EXPENSE', 'label': 'Despesas essenciais'},
        {'value': 'LIFESTYLE_EXPENSE', 'label': 'Estilo de vida'},
        {'value': 'GOAL', 'label': 'Metas e sonhos'},
        {'value': 'OTHER', 'label': 'Outros'},
      ];
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final Map<String, dynamic> categoryData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'group': _selectedGroup,
        'color': _selectedColor,
      };
      
      // Adicionar is_system_default apenas se estiver marcado
      // (para criar categorias globais que são padrão do sistema)
      if (_isSystemDefault) {
        categoryData['is_system_default'] = true;
      }

      await widget.onSave(categoryData);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.toString()}'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _CategoryDetailsDialog extends StatelessWidget {
  const _CategoryDetailsDialog({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = category['name'] as String? ?? '';
    final type = category['type'] as String? ?? '';
    final group = category['group'] as String?;
    final color = category['color'] as String?;
    final isSystemDefault = category['is_system_default'] as bool? ?? false;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Detalhes da Categoria',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícone e nome
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _parseColor(color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _parseColor(color).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              _getCategoryIcon(name, type),
              color: _parseColor(color),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // Informações
          _DetailRow(label: 'Tipo', value: _getTypeLabel(type)),
          if (group != null) _DetailRow(label: 'Grupo', value: _getGroupLabel(group)),
          if (isSystemDefault)
            const _DetailRow(
              label: 'Sistema',
              value: 'Categoria padrão',
              valueColor: AppColors.primary,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Fechar', style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Editar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
        ),
        ElevatedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete, size: 18),
          label: const Text('Excluir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.alert,
          ),
        ),
      ],
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null) return AppColors.primary;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String name, String type) {
    final lowerName = name.toLowerCase();
    
    if (lowerName.contains('salário') || lowerName.contains('salario')) {
      return Icons.work_outline;
    }
    if (lowerName.contains('investimento')) return Icons.trending_up;
    if (lowerName.contains('alimentação') || lowerName.contains('alimentacao')) {
      return Icons.shopping_cart_outlined;
    }
    if (lowerName.contains('transporte')) return Icons.directions_car_outlined;
    if (lowerName.contains('moradia')) return Icons.home_outlined;
    
    return type == 'INCOME'
        ? Icons.arrow_downward
        : Icons.shopping_cart_outlined;
  }

  String _getTypeLabel(String type) {
    return type == 'INCOME' ? 'Receita' : 'Despesa';
  }

  String _getGroupLabel(String group) {
    const labels = {
      'REGULAR_INCOME': 'Renda principal',
      'EXTRA_INCOME': 'Renda extra',
      'SAVINGS': 'Poupança / Reserva',
      'INVESTMENT': 'Investimentos',
      'ESSENTIAL_EXPENSE': 'Despesas essenciais',
      'LIFESTYLE_EXPENSE': 'Estilo de vida',
      'GOAL': 'Metas e sonhos',
      'OTHER': 'Outros',
    };
    return labels[group] ?? group;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = category['name'] as String? ?? '';
    final type = category['type'] as String? ?? '';
    final group = category['group'] as String?;
    final color = category['color'] as String?;
    final isSystemDefault = category['is_system_default'] as bool? ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Ícone da categoria
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _parseColor(color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _parseColor(color).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _getCategoryIcon(name, type),
                  color: _parseColor(color),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Informações da categoria
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSystemDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'PADRÃO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (group != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getGroupLabel(group),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Badge do tipo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getTypeColor(type).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getTypeLabel(type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getTypeColor(type),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botões de ação
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
                color: const Color(0xFF2A2A2A),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Editar',
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: AppColors.alert),
                        const SizedBox(width: 12),
                        Text(
                          'Excluir',
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null) return AppColors.primary;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String name, String type) {
    final lowerName = name.toLowerCase();
    
    // Receitas
    if (lowerName.contains('salário') || lowerName.contains('salario')) {
      return Icons.work_outline;
    }
    if (lowerName.contains('investimento')) return Icons.trending_up;
    if (lowerName.contains('freelance') || lowerName.contains('extra')) {
      return Icons.monetization_on_outlined;
    }
    if (lowerName.contains('dividendo')) return Icons.account_balance_wallet_outlined;
    if (lowerName.contains('bônus') || lowerName.contains('bonus')) return Icons.card_giftcard_outlined;
    
    // Despesas - Essenciais
    if (lowerName.contains('alimentação') || lowerName.contains('alimentacao') || 
        lowerName.contains('mercado') || lowerName.contains('supermercado')) {
      return Icons.shopping_cart_outlined;
    }
    if (lowerName.contains('restaurante') || lowerName.contains('delivery')) {
      return Icons.restaurant_outlined;
    }
    if (lowerName.contains('transporte') || lowerName.contains('combustível') || 
        lowerName.contains('combustivel') || lowerName.contains('gasolina')) {
      return Icons.directions_car_outlined;
    }
    if (lowerName.contains('moradia') || lowerName.contains('aluguel') || 
        lowerName.contains('condomínio') || lowerName.contains('condominio')) {
      return Icons.home_outlined;
    }
    if (lowerName.contains('saúde') || lowerName.contains('saude') || 
        lowerName.contains('médico') || lowerName.contains('medico') ||
        lowerName.contains('farmácia') || lowerName.contains('farmacia')) {
      return Icons.medical_services_outlined;
    }
    if (lowerName.contains('educação') || lowerName.contains('educacao') ||
        lowerName.contains('escola') || lowerName.contains('curso')) {
      return Icons.school_outlined;
    }
    
    // Despesas - Estilo de vida
    if (lowerName.contains('lazer') || lowerName.contains('entretenimento') ||
        lowerName.contains('diversão') || lowerName.contains('diversao')) {
      return Icons.celebration_outlined;
    }
    if (lowerName.contains('academia') || lowerName.contains('esporte')) {
      return Icons.fitness_center_outlined;
    }
    if (lowerName.contains('vestuário') || lowerName.contains('vestuario') ||
        lowerName.contains('roupa') || lowerName.contains('shopping')) {
      return Icons.shopping_bag_outlined;
    }
    if (lowerName.contains('viagem') || lowerName.contains('férias') || 
        lowerName.contains('ferias')) {
      return Icons.flight_outlined;
    }
    if (lowerName.contains('assinatura') || lowerName.contains('streaming')) {
      return Icons.subscriptions_outlined;
    }
    
    // Despesas - Financeiro
    if (lowerName.contains('cartão') || lowerName.contains('cartao')) {
      return Icons.credit_card_outlined;
    }
    if (lowerName.contains('empréstimo') || lowerName.contains('emprestimo')) {
      return Icons.account_balance_outlined;
    }
    if (lowerName.contains('financiamento')) return Icons.car_rental_outlined;
    if (lowerName.contains('tarifa') || lowerName.contains('taxa')) {
      return Icons.receipt_long_outlined;
    }
    if (lowerName.contains('seguro')) return Icons.shield_outlined;
    
    // Outros
    if (lowerName.contains('pet') || lowerName.contains('animal')) {
      return Icons.pets_outlined;
    }
    if (lowerName.contains('telefone') || lowerName.contains('celular') ||
        lowerName.contains('internet')) {
      return Icons.phone_android_outlined;
    }
    if (lowerName.contains('presente') || lowerName.contains('doação') ||
        lowerName.contains('doacao')) {
      return Icons.card_giftcard_outlined;
    }
    
    // Padrão por tipo
    switch (type) {
      case 'INCOME':
        return Icons.arrow_downward;
      case 'EXPENSE':
        return Icons.shopping_cart_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'INCOME':
        return 'Receita';
      case 'EXPENSE':
        return 'Despesa';
      default:
        return type;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'INCOME':
        return AppColors.success;
      case 'EXPENSE':
        return AppColors.alert;
      default:
        return Colors.grey;
    }
  }

  String _getGroupLabel(String group) {
    switch (group) {
      case 'REGULAR_INCOME':
        return 'Renda principal';
      case 'EXTRA_INCOME':
        return 'Renda extra';
      case 'SAVINGS':
        return 'Poupança / Reserva';
      case 'INVESTMENT':
        return 'Investimentos';
      case 'ESSENTIAL_EXPENSE':
        return 'Despesas essenciais';
      case 'LIFESTYLE_EXPENSE':
        return 'Estilo de vida';
      case 'GOAL':
        return 'Metas e sonhos';
      case 'OTHER':
        return 'Outros';
      default:
        return group;
    }
  }
}
