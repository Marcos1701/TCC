import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/models/category.dart';
import 'category_form_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _repository = FinanceRepository();
  bool _isLoading = true;
  List<CategoryModel> _allCategories = [];
  List<CategoryModel> _filteredCategories = [];
  String _searchQuery = '';
  String _selectedType = 'ALL'; // ALL, INCOME, EXPENSE

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _repository.fetchCategories();
      setState(() {
        _allCategories = categories;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar categorias: $e'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    _filteredCategories = _allCategories.where((category) {
      // Filtro de tipo
      if (_selectedType != 'ALL' && category.type != _selectedType) {
        return false;
      }

      // Filtro de busca
      if (_searchQuery.isNotEmpty) {
        return category.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }

      return true;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      _applyFilters();
    });
  }

  Future<void> _createCategory() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryFormPage(),
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  Future<void> _editCategory(CategoryModel category) async {
    // Verificar se é categoria global (não pode editar)
    if (!category.isUserCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Categorias globais não podem ser editadas'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryFormPage(
          category: {
            'id': category.id,
            'name': category.name,
            'type': category.type,
            'color': category.color ?? '#808080',
            'group': category.group,
          },
        ),
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    // Verificar se é categoria global (não pode deletar)
    if (!category.isUserCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Categorias globais não podem ser deletadas'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Confirmação
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Categoria'),
        content: Text(
          'Tem certeza que deseja deletar "${category.name}"?\n\n'
          'Esta ação não pode ser desfeita e pode falhar se a categoria '
          'estiver sendo usada em transações ou metas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alert),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.deleteCategory(category.id.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Categoria deletada com sucesso'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        // Extrair mensagem de erro mais amigável
        String errorMessage = 'Erro ao deletar categoria';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('transação') || errorStr.contains('transaction')) {
          errorMessage = 'Esta categoria possui transações vinculadas.\nReatribua as transações antes de excluir.';
        } else if (errorStr.contains('meta') || errorStr.contains('goal')) {
          errorMessage = 'Esta categoria possui metas vinculadas.\nReatribua as metas antes de excluir.';
        } else if (errorStr.contains('sistema') || errorStr.contains('system') || errorStr.contains('padrão')) {
          errorMessage = 'Categorias do sistema não podem ser excluídas.';
        } else if (errorStr.contains('vinculada')) {
          // Capturar qualquer mensagem que mencione algo vinculado
          errorMessage = 'Esta categoria está em uso e não pode ser excluída.';
        } else if (errorStr.contains('400') || errorStr.contains('bad request')) {
          errorMessage = 'Não foi possível excluir esta categoria.\nEla pode estar em uso em transações ou metas.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.alert,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separar categorias globais e personalizadas
    final globalCategories = _filteredCategories
        .where((c) => !c.isUserCreated)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final userCategories = _filteredCategories
        .where((c) => c.isUserCreated)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar categoria...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),

          // Filtro de tipo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Todas', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('Receitas', 'INCOME'),
                const SizedBox(width: 8),
                _buildFilterChip('Despesas', 'EXPENSE'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Lista de categorias
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadCategories,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Categorias Globais
                        if (globalCategories.isNotEmpty) ...[
                          const Text(
                            'Categorias do Sistema',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...globalCategories.map((category) =>
                              _buildCategoryCard(category, isGlobal: true)),
                          const SizedBox(height: 24),
                        ],

                        // Categorias Personalizadas
                        if (userCategories.isNotEmpty) ...[
                          const Text(
                            'Minhas Categorias',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...userCategories.map((category) =>
                              _buildCategoryCard(category, isGlobal: false)),
                        ],

                        // Mensagem se vazio
                        if (_filteredCategories.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Nenhuma categoria encontrada',
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCategory,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria'),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isSelected = _selectedType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onTypeChanged(type),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildCategoryCard(CategoryModel category, {required bool isGlobal}) {
    final colorValue = category.color ?? '#808080';
    Color categoryColor;
    try {
      categoryColor = Color(
        int.parse(colorValue.replaceFirst('#', '0xFF')),
      );
    } catch (e) {
      categoryColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: categoryColor,
          child: Icon(
            category.type == 'INCOME'
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isGlobal) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'GLOBAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          category.type == 'INCOME' ? 'Receita' : 'Despesa',
          style: TextStyle(
            color: category.type == 'INCOME' 
                ? AppColors.support 
                : AppColors.alert,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: isGlobal
            ? const Icon(Icons.lock, size: 20)
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editCategory(category);
                  } else if (value == 'delete') {
                    _deleteCategory(category);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: AppColors.alert),
                        const SizedBox(width: 8),
                        Text('Deletar', style: TextStyle(color: AppColors.alert)),
                      ],
                    ),
                  ),
                ],
              ),
        onTap: isGlobal ? null : () => _editCategory(category),
      ),
    );
  }
}
