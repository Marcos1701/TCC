import 'package:flutter/material.dart';
import '../../../../core/models/category.dart';
import '../../../../core/repositories/category_repository.dart';

/// Widget para seleção de categoria com filtro por tipo
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.label = 'Categoria Alvo',
    this.hint = 'Selecione a categoria',
    this.categoryType,
  });

  final CategoryModel? selectedCategory;
  final ValueChanged<CategoryModel?> onCategorySelected;
  final String label;
  final String hint;
  final String? categoryType; // 'EXPENSE' ou 'INCOME' para filtrar

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showCategoryPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedCategory?.name ?? hint,
                    style: TextStyle(
                      color: selectedCategory != null
                          ? Colors.black87
                          : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (selectedCategory != null && categoryType != null) ...[
          const SizedBox(height: 4),
          Text(
            'Tipo: ${selectedCategory!.type == "EXPENSE" ? "Despesa" : "Receita"}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ],
    );
  }

  Future<void> _showCategoryPicker(BuildContext context) async {
    try {
      // Buscar categorias via repository
      final repository = CategoryRepository();
      final categories = await repository.fetchCategories();

      // Filtrar por tipo se especificado
      final filteredCategories = categoryType != null
          ? categories.where((cat) => cat.type == categoryType).toList()
          : categories;

      if (!context.mounted) return;

      // Mostrar em bottom sheet
      final selected = await showModalBottomSheet<CategoryModel>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Selecionar Categoria',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Lista de categorias
                Expanded(
                  child: filteredCategories.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma categoria encontrada',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, index) {
                            final category = filteredCategories[index];
                            final isSelected = category.id == selectedCategory?.id;
                            
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: category.color != null
                                      ? Color(int.parse('0xFF${category.color}'))
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '📁',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              title: Text(category.name),
                              subtitle: Text(
                                category.type == 'EXPENSE' ? 'Despesa' : 'Receita',
                                style: TextStyle(
                                  color: category.type == 'EXPENSE'
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                                  : null,
                              selected: isSelected,
                              onTap: () => Navigator.pop(context, category),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );

      if (selected != null) {
        onCategorySelected(selected);
      }
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar categorias: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
