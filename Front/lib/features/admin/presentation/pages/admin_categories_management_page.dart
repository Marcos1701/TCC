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

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
    if (_filterType == 'ALL') return _categories;
    return _categories
        .where((cat) => cat['type'] == _filterType)
        .toList();
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
        ],
      ),
      body: Column(
        children: [
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

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Tipo:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<String>(
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
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'ALL',
                      label: Text('Todas', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: 'INCOME',
                      label: Text('Receita', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: 'EXPENSE',
                      label: Text('Despesa', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: 'DEBT',
                      label: Text('Dívida', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_filteredCategories.length} categorias globais',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma categoria encontrada',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Todas as categorias são criadas pelo sistema',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
          if (_filterType == 'ALL' || _filterType == 'DEBT')
            _buildCategorySection('DEBT', 'Dívidas', byType['DEBT'] ?? []),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
          ),
          child: Column(
            children: [
              for (var i = 0; i < categories.length; i++) ...[
                _CategoryTile(category: categories[i]),
                if (i < categories.length - 1) Divider(height: 1, color: Colors.grey[800]),
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
      case 'DEBT':
        return Icons.credit_card;
      default:
        return Icons.category;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'INCOME':
        return Colors.green;
      case 'EXPENSE':
        return Colors.red;
      case 'DEBT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Map<String, dynamic> category;

  @override
  Widget build(BuildContext context) {
    final name = category['name'] as String? ?? '';
    final type = category['type'] as String? ?? '';
    final group = category['group'] as String?;
    final color = category['color'] as String?;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _parseColor(color).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getCategoryIcon(name, type),
          color: _parseColor(color),
          size: 22,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      subtitle: group != null
          ? Text(
              _getGroupLabel(group),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            )
          : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _getTypeColor(type).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
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
      return Icons.work;
    }
    if (lowerName.contains('investimento')) return Icons.trending_up;
    if (lowerName.contains('freelance') || lowerName.contains('extra')) {
      return Icons.monetization_on;
    }
    
    // Despesas
    if (lowerName.contains('alimentação') || lowerName.contains('alimentacao')) {
      return Icons.restaurant;
    }
    if (lowerName.contains('transporte')) return Icons.directions_car;
    if (lowerName.contains('moradia') || lowerName.contains('aluguel')) {
      return Icons.home;
    }
    if (lowerName.contains('saúde') || lowerName.contains('saude')) {
      return Icons.medical_services;
    }
    if (lowerName.contains('educação') || lowerName.contains('educacao')) {
      return Icons.school;
    }
    if (lowerName.contains('lazer') || lowerName.contains('entretenimento')) {
      return Icons.sports_esports;
    }
    
    // Dívidas
    if (lowerName.contains('cartão') || lowerName.contains('cartao')) {
      return Icons.credit_card;
    }
    if (lowerName.contains('empréstimo') || lowerName.contains('emprestimo')) {
      return Icons.account_balance;
    }
    if (lowerName.contains('financiamento')) return Icons.car_rental;
    
    // Padrão por tipo
    switch (type) {
      case 'INCOME':
        return Icons.arrow_downward;
      case 'EXPENSE':
        return Icons.shopping_cart;
      case 'DEBT':
        return Icons.credit_card;
      default:
        return Icons.category;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'INCOME':
        return 'Receita';
      case 'EXPENSE':
        return 'Despesa';
      case 'DEBT':
        return 'Dívida';
      default:
        return type;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'INCOME':
        return Colors.green;
      case 'EXPENSE':
        return Colors.red;
      case 'DEBT':
        return Colors.orange;
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
      case 'INVESTMENT_INCOME':
        return 'Investimentos';
      case 'ESSENTIAL_EXPENSE':
        return 'Essencial';
      case 'LIFESTYLE_EXPENSE':
        return 'Estilo de vida';
      case 'VARIABLE_EXPENSE':
        return 'Variável';
      case 'FINANCIAL_EXPENSE':
        return 'Financeiro';
      case 'CREDIT_CARD_DEBT':
        return 'Cartão de crédito';
      case 'LOAN_DEBT':
        return 'Empréstimo';
      case 'FINANCING_DEBT':
        return 'Financiamento';
      default:
        return group;
    }
  }
}
