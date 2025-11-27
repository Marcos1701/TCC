import 'package:flutter/material.dart';

import '../data/admin_viewmodel.dart';

/// Página de Gerenciamento de Categorias do Sistema.
///
/// Esta tela permite ao administrador gerenciar as categorias padrão
/// que são automaticamente criadas para novos usuários do sistema.
/// As operações disponíveis incluem:
///
/// - Visualização das categorias separadas por tipo (Receitas/Despesas);
/// - Criação de novas categorias padrão;
/// - Remoção de categorias existentes.
///
/// As categorias são fundamentais para a classificação das transações
/// financeiras dos usuários, permitindo análises e relatórios precisos.
///
/// Desenvolvido como parte do TCC - Sistema de Educação Financeira Gamificada.
class AdminCategoriesPage extends StatefulWidget {
  /// Cria uma nova instância da página de gerenciamento de categorias.
  const AdminCategoriesPage({super.key, required this.viewModel});

  /// ViewModel responsável pelo gerenciamento de estado das categorias.
  final AdminViewModel viewModel;

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  String? _filtroTipo;

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categorias do Sistema',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gerencie as categorias padrão criadas para novos usuários',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showCreateCategoryDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Nova Categoria'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filtro de tipo
                  SegmentedButton<String?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('Todas')),
                      ButtonSegment(value: 'INCOME', label: Text('Receitas')),
                      ButtonSegment(value: 'EXPENSE', label: Text('Despesas')),
                    ],
                    selected: {_filtroTipo},
                    onSelectionChanged: (selection) {
                      setState(() => _filtroTipo = selection.first);
                      widget.viewModel.loadCategories(tipo: _filtroTipo);
                    },
                  ),
                ],
              ),
            ),

            // Lista de categorias
            Expanded(
              child: _buildCategoriesList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoriesList() {
    final viewModel = widget.viewModel;

    if (viewModel.isLoading && viewModel.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null && viewModel.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(viewModel.errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.loadCategories(tipo: _filtroTipo),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (viewModel.categories.isEmpty) {
      return const Center(
        child: Text('Nenhuma categoria encontrada'),
      );
    }

    // Separar por tipo
    final receitas = viewModel.categories
        .where((c) => c['type'] == 'INCOME')
        .toList();
    final despesas = viewModel.categories
        .where((c) => c['type'] == 'EXPENSE')
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        if (_filtroTipo == null || _filtroTipo == 'INCOME') ...[
          _CategorySection(
            title: 'Receitas',
            icon: Icons.arrow_upward,
            color: Colors.green,
            categories: receitas,
            onDelete: _deleteCategory,
          ),
          const SizedBox(height: 24),
        ],
        if (_filtroTipo == null || _filtroTipo == 'EXPENSE') ...[
          _CategorySection(
            title: 'Despesas',
            icon: Icons.arrow_downward,
            color: Colors.red,
            categories: despesas,
            onDelete: _deleteCategory,
          ),
        ],
      ],
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text(
          'Deseja realmente excluir a categoria "${category['name']}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final id = category['id'] as int;
      final sucesso = await widget.viewModel.deleteCategory(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sucesso ? 'Categoria excluída!' : 'Erro ao excluir categoria',
            ),
            backgroundColor: sucesso ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateCategoryDialog() {
    final nomeController = TextEditingController();
    String tipo = 'EXPENSE';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Categoria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da categoria',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'INCOME', label: Text('Receita')),
                  ButtonSegment(value: 'EXPENSE', label: Text('Despesa')),
                ],
                selected: {tipo},
                onSelectionChanged: (selection) {
                  setDialogState(() => tipo = selection.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                if (nome.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Digite o nome da categoria'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                final resultado = await widget.viewModel.createCategory(
                  nome: nome,
                  tipo: tipo,
                );

                if (mounted) {
                  final sucesso = resultado['sucesso'] == true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sucesso
                            ? 'Categoria criada com sucesso!'
                            : resultado['erro'] ?? 'Erro ao criar categoria',
                      ),
                      backgroundColor: sucesso ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seção de categorias por tipo.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.categories,
    required this.onDelete,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> categories;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${categories.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Nenhuma categoria de ${title.toLowerCase()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              return _CategoryChip(
                category: cat,
                color: color,
                onDelete: () => onDelete(cat),
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// Chip de categoria individual.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.color,
    required this.onDelete,
  });

  final Map<String, dynamic> category;
  final Color color;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nome = category['name'] as String? ?? 'Sem nome';

    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(Icons.category, size: 16, color: color),
      ),
      label: Text(nome),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDelete,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}
