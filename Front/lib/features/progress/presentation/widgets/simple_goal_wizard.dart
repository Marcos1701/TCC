import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/models/goal.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import 'goal_wizard_components.dart';

/// Wizard simplificado para criação de metas
/// 
/// Fluxo de 4 passos:
/// 1. Objetivo: Tipo (Juntar dinheiro ou Personalizada)
/// 2. Nome: Título com templates ou customizado
/// 3. Valor: Meta financeira
/// 4. Prazo: Data limite (opcional)
class SimpleGoalWizard extends StatefulWidget {
  const SimpleGoalWizard({super.key});

  @override
  State<SimpleGoalWizard> createState() => _SimpleGoalWizardState();
}

class _SimpleGoalWizardState extends State<SimpleGoalWizard> {
  final FinanceRepository _repository = FinanceRepository();
  final PageController _pageController = PageController();
  final NumberFormat _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  int _currentStep = 0;
  GoalType? _selectedType;
  String _title = '';
  double _targetAmount = 0;
  DateTime? _deadline;
  bool _isCreating = false;
  
  // Category selection - suporte a múltiplas categorias
  List<CategoryModel> _availableCategories = [];
  Set<CategoryModel> _selectedCategories = {};  // Múltiplas categorias
  bool _useDefaultCategories = true;
  double _baselineAmount = 0;
  bool _loadingCategories = false;
  
  static const int _maxCategories = 5;  // Limite de categorias

  // Templates sugeridos por tipo
  final Map<GoalType, List<String>> _templates = {
    GoalType.savings: [
      '📱 Celular novo',
      '✈️ Viagem dos sonhos',
      '🏠 Entrada do apartamento',
      '🚗 Carro próprio',
      '🎓 Curso/Educação',
    ],
    GoalType.expenseReduction: [
      '🍔 Reduzir delivery',
      '☕ Menos café na rua',
      '🎮 Gastos com jogos',
      '📺 Assinaturas streaming',
      '🛒 Compras por impulso',
    ],
    GoalType.incomeIncrease: [
      '💼 Renda extra',
      '📈 Aumento salarial',
      '🎯 Meta de vendas',
      '💻 Freelance',
    ],
    GoalType.emergencyFund: [
      '🛡️ Reserva 3 meses',
      '🛡️ Reserva 6 meses',
      '🛡️ Reserva 12 meses',
    ],
    GoalType.custom: [
      '🎯 Meta personalizada',
      '💪 Desafio pessoal',
      '🏆 Conquista especial',
    ],
  };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!mounted) return;
    final totalSteps = _getTotalSteps();
    if (_currentStep < totalSteps - 1) {
      setState(() => _currentStep++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
  
  int _getTotalSteps() {
    // CUSTOM não precisa de step de categoria
    if (_selectedType == GoalType.custom) return 4;
    return 5; // Tipo -> Categoria -> Nome -> Valor -> Prazo
  }
  
  bool _needsCategoryStep() {
    return _selectedType != null && _selectedType != GoalType.custom;
  }
  
  Future<void> _loadCategories() async {
    if (_loadingCategories) return;
    setState(() => _loadingCategories = true);
    
    try {
      String? typeFilter;
      if (_selectedType == GoalType.expenseReduction) {
        typeFilter = 'EXPENSE';
      } else if (_selectedType == GoalType.incomeIncrease) {
        typeFilter = 'INCOME';
      }
      // Para SAVINGS e EMERGENCY_FUND, buscamos EXPENSE (pois são transações de saída para poupança)
      typeFilter ??= 'EXPENSE';
      
      final categories = await _repository.fetchCategories(type: typeFilter);
      
      if (mounted) {
        setState(() {
          _availableCategories = categories;
          _loadingCategories = false;
          
          // Para EXPENSE_REDUCTION, não pré-selecionar
          if (_selectedType == GoalType.expenseReduction) {
            _useDefaultCategories = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCategories = false);
        FeedbackService.showError(context, 'Erro ao carregar categorias');
      }
    }
  }

  void _previousStep() {
    if (!mounted) return;
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  /// Valida os campos obrigatórios antes de submeter ao backend
  String? _validateBeforeSubmit() {
    // Validação para EXPENSE_REDUCTION
    if (_selectedType == GoalType.expenseReduction) {
      if (_selectedCategories.isEmpty) {
        return 'Selecione pelo menos uma categoria para reduzir gastos';
      }
      if (_selectedCategories.length > _maxCategories) {
        return 'Máximo de $_maxCategories categorias por meta';
      }
      if (_baselineAmount <= 0) {
        return 'Informe quanto você gasta atualmente nessas categorias';
      }
      if (_targetAmount >= _baselineAmount) {
        return 'A meta de redução deve ser menor que o gasto atual (R\$ ${_baselineAmount.toStringAsFixed(2)})';
      }
    }
    
    // Validação para INCOME_INCREASE
    if (_selectedType == GoalType.incomeIncrease && _baselineAmount <= 0) {
      return 'Informe sua receita média mensal atual';
    }
    
    // Validações gerais
    if (_title.trim().isEmpty) {
      return 'Informe um título para a meta';
    }
    if (_targetAmount <= 0) {
      return 'Informe um valor para a meta';
    }
    
    return null;
  }
  
  /// Extrai mensagem de erro amigável da resposta da API
  String _extractErrorMessage(dynamic error) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        // Mapear campos para nomes amigáveis
        final fieldNames = {
          'target_categories': 'Categorias',
          'target_category': 'Categoria alvo',
          'baseline_amount': 'Valor base',
          'target_amount': 'Valor da meta',
          'title': 'Título',
          'goal_type': 'Tipo de meta',
          'non_field_errors': 'Erro',
        };
        
        for (final entry in data.entries) {
          final fieldName = fieldNames[entry.key] ?? entry.key;
          final message = entry.value is List 
              ? (entry.value as List).join(', ')
              : entry.value.toString();
          return '$fieldName: $message';
        }
      }
    }
    return error.toString();
  }

  Future<void> _createGoal() async {
    if (_isCreating) return;
    
    // Validação pré-submit
    final validationError = _validateBeforeSubmit();
    if (validationError != null) {
      FeedbackService.showError(context, validationError);
      return;
    }
    
    setState(() => _isCreating = true);

    try {
      // Converte categorias para lista de IDs
      final categoryIds = _selectedCategories.map((c) => c.id.toString()).toList();
      
      await _repository.createGoal(
        title: _title,
        description: '',
        targetAmount: _targetAmount,
        currentAmount: 0,
        initialAmount: 0,
        deadline: _deadline,
        goalType: _selectedType!.value,
        targetCategories: categoryIds.isNotEmpty ? categoryIds : null,
        baselineAmount: _baselineAmount > 0 ? _baselineAmount : null,
      );

      AnalyticsService.trackGoalCreated(
        goalType: _selectedType!.value,
        targetAmount: _targetAmount,
        hasDeadline: _deadline != null,
        creationMethod: 'wizard',
      );

      if (mounted) {
        FeedbackService.showSuccess(
          context,
          '🎯 Meta criada com sucesso!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _extractErrorMessage(e);
        FeedbackService.showError(
          context,
          'Erro ao criar meta: $errorMessage',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nova Meta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Type(),
                  if (_needsCategoryStep()) _buildStepCategory(),
                  _buildStep2Title(),
                  _buildStep3Amount(),
                  _buildStep4Deadline(),
                ],
              ),
            ),
            
            // Navigation buttons
            if (_currentStep > 0)
              _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final totalSteps = _getTotalSteps();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < totalSteps - 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _previousStep,
            icon: const Icon(Icons.arrow_back, color: Colors.grey),
            label: const Text('Voltar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // STEP 1: Escolher tipo
  Widget _buildStep1Type() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Qual é o seu objetivo?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha o tipo de meta que você deseja criar',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Opção: Juntar dinheiro
            GoalTypeCard(
              icon: Icons.savings_outlined,
              iconColor: Colors.green,
              title: 'Juntar dinheiro',
              description: 'Economizar para um objetivo específico',
              examples: '📱 Celular, ✈️ Viagem, 🏠 Casa própria',
              trackedInfo: 'Padrão: Poupança e Investimentos',
              isSelected: _selectedType == GoalType.savings,
              onTap: () {
                setState(() => _selectedType = GoalType.savings);
                _loadCategories();
                _nextStep();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Opção: Reduzir gastos
            GoalTypeCard(
              icon: Icons.trending_down_outlined,
              iconColor: Colors.orange,
              title: 'Reduzir gastos',
              description: 'Diminuir despesas em uma categoria',
              examples: '🍔 Delivery, ☕ Café, 📺 Assinaturas',
              trackedInfo: 'Você escolherá a categoria',
              isSelected: _selectedType == GoalType.expenseReduction,
              onTap: () {
                setState(() => _selectedType = GoalType.expenseReduction);
                _loadCategories();
                _nextStep();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Opção: Aumentar receita
            GoalTypeCard(
              icon: Icons.trending_up_outlined,
              iconColor: Colors.blue,
              title: 'Aumentar receita',
              description: 'Alcançar uma meta de renda',
              examples: '💼 Renda extra, 📈 Aumento, 💻 Freelance',
              trackedInfo: 'Padrão: Todas as receitas',
              isSelected: _selectedType == GoalType.incomeIncrease,
              onTap: () {
                setState(() => _selectedType = GoalType.incomeIncrease);
                _loadCategories();
                _nextStep();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Opção: Fundo de emergência
            GoalTypeCard(
              icon: Icons.shield_outlined,
              iconColor: Colors.purple,
              title: 'Fundo de emergência',
              description: 'Criar uma reserva financeira',
              examples: '🛡️ Reserva 3, 6 ou 12 meses',
              trackedInfo: 'Padrão: Poupança e Investimentos',
              isSelected: _selectedType == GoalType.emergencyFund,
              onTap: () {
                setState(() => _selectedType = GoalType.emergencyFund);
                _loadCategories();
                _nextStep();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Opção: Meta personalizada
            GoalTypeCard(
              icon: Icons.edit_outlined,
              iconColor: Colors.grey,
              title: 'Meta personalizada',
              description: 'Crie uma meta customizada',
              examples: '🎯 Qualquer objetivo',
              trackedInfo: 'Atualização manual',
              isSelected: _selectedType == GoalType.custom,
              onTap: () {
                setState(() => _selectedType = GoalType.custom);
                _nextStep();
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // STEP CATEGORY: Escolher categorias para monitorar
  Widget _buildStepCategory() {
    final isExpenseReduction = _selectedType == GoalType.expenseReduction;
    final isIncomeIncrease = _selectedType == GoalType.incomeIncrease;
    
    String title;
    String subtitle;
    String defaultLabel;
    
    if (isExpenseReduction) {
      title = 'Qual categoria reduzir?';
      subtitle = 'Selecione a categoria de despesa que você quer diminuir';
      defaultLabel = '';
    } else if (isIncomeIncrease) {
      title = 'Quais receitas monitorar?';
      subtitle = 'Por padrão, monitoramos todas suas receitas';
      defaultLabel = 'Todas as receitas';
    } else {
      title = 'Quais categorias monitorar?';
      subtitle = 'Por padrão, monitoramos Poupança e Investimentos';
      defaultLabel = 'Poupança e Investimentos';
    }
    
    // Texto adicional para seleção múltipla
    final multipleSelectionHint = isExpenseReduction 
        ? 'Selecione até $_maxCategories categorias'
        : subtitle;
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              multipleSelectionHint,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            // Mostrar contador de categorias selecionadas
            if (isExpenseReduction && _selectedCategories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_selectedCategories.length} categoria(s) selecionada(s)',
                  style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(height: 24),
            
            // Loading state
            if (_loadingCategories)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              // Para tipos que não são EXPENSE_REDUCTION, mostrar opção padrão
              if (!isExpenseReduction) ...[
                _buildDefaultCategoryOption(defaultLabel),
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Ou escolha uma categoria específica:',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 12),
              ],
              
              // Lista de categorias
              ..._availableCategories.map((category) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCategoryOption(category),
              )),
              
              if (_availableCategories.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nenhuma categoria encontrada. Crie categorias primeiro.',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Baseline amount para EXPENSE_REDUCTION e INCOME_INCREASE
              if ((isExpenseReduction && _selectedCategories.isNotEmpty) || 
                  (isIncomeIncrease && !_useDefaultCategories) ||
                  (isIncomeIncrease && _useDefaultCategories)) ...[
                const SizedBox(height: 24),
                RichText(
                  text: TextSpan(
                    text: isExpenseReduction 
                        ? 'Quanto você gasta em média nessas categorias? '
                        : 'Qual sua receita média mensal atual? ',
                    style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    children: const [
                      TextSpan(
                        text: '*',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpenseReduction
                      ? 'Sua meta de redução deve ser menor que este valor'
                      : 'Este valor será usado para comparar seu progresso',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'R\$ 0,00 / mês',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixText: 'R\$ ',
                    prefixStyle: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    CurrencyInputFormatter(),
                  ],
                  onChanged: (value) {
                    final cleanValue = value.replaceAll('.', '').replaceAll(',', '.');
                    setState(() => _baselineAmount = double.tryParse(cleanValue) ?? 0);
                  },
                ),
              ],
            ],
            
            const SizedBox(height: 32),
            
            // Botão continuar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canProceedFromCategoryStep() ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  bool _canProceedFromCategoryStep() {
    // EXPENSE_REDUCTION requer pelo menos uma categoria selecionada e baseline
    if (_selectedType == GoalType.expenseReduction) {
      return _selectedCategories.isNotEmpty && _baselineAmount > 0;
    }
    // INCOME_INCREASE requer baseline
    if (_selectedType == GoalType.incomeIncrease) {
      return _baselineAmount > 0;
    }
    // Outros tipos podem usar padrão ou categoria específica
    return true;
  }
  
  Widget _buildDefaultCategoryOption(String label) {
    final isSelected = _useDefaultCategories;
    return Material(
      color: isSelected 
          ? AppColors.primary.withOpacity(0.2)
          : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _useDefaultCategories = true;
            _selectedCategories.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usar padrão',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCategoryOption(CategoryModel category) {
    final isSelected = _selectedCategories.contains(category);
    final canAddMore = _selectedCategories.length < _maxCategories;
    final categoryColor = _parseColor(category.color);
    
    return Material(
      color: isSelected 
          ? AppColors.primary.withOpacity(0.2)
          : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _useDefaultCategories = false;
            if (isSelected) {
              _selectedCategories.remove(category);
            } else if (canAddMore) {
              _selectedCategories.add(category);
            } else {
              // Limite atingido, mostrar feedback
              FeedbackService.showWarning(context, 'Máximo de $_maxCategories categorias');
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.grey;
    }
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  // STEP 2: Escolher título
  Widget _buildStep2Title() {
    final templates = _templates[_selectedType] ?? [];
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dê um nome para sua meta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha um template ou crie o seu próprio',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Templates
            const Text(
              'Sugestões populares:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Lista de templates
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final isSelected = _title == template;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected 
                          ? AppColors.primary.withOpacity(0.2)
                          : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() => _title = template);
                          _nextStep();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey[800]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(template, style: const TextStyle(color: Colors.white, fontSize: 16)),
                              const Spacer(),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
          
            // Campo customizado
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ou digite seu próprio título...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                suffixIcon: _title.isNotEmpty && !templates.contains(_title)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                        onPressed: _nextStep,
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _title = value),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() => _title = value.trim());
                  _nextStep();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // STEP 3: Definir valor alvo
  Widget _buildStep3Amount() {
    final controller = TextEditingController(
      text: _targetAmount > 0 ? CurrencyInputFormatter.format(_targetAmount) : '',
    );
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qual o valor da meta?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quanto você quer juntar?',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          // Input de valor
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'R\$ 0,00',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 32),
              border: InputBorder.none,
              prefixIcon: const SizedBox(width: 48),
              suffixIcon: const SizedBox(width: 48),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
              CurrencyInputFormatter(),
            ],
            onChanged: (value) {
              final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
              if (cleanValue.isNotEmpty) {
                setState(() => _targetAmount = double.parse(cleanValue) / 100);
              } else {
                setState(() => _targetAmount = 0);
              }
            },
          ),
          
          const SizedBox(height: 32),
          
          // Sugestões rápidas
          const Text(
            'Sugestões:',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [500, 1000, 2000, 5000, 10000].map((amount) {
              return ActionChip(
                label: Text(_currency.format(amount)),
                labelStyle: const TextStyle(color: Colors.white),
                backgroundColor: const Color(0xFF1E1E1E),
                side: BorderSide(color: Colors.grey[800]!),
                onPressed: () {
                  setState(() => _targetAmount = amount.toDouble());
                  controller.text = CurrencyInputFormatter.format(amount.toDouble());
                },
              );
            }).toList(),
          ),
          
          const Spacer(),
          
          // Botão continuar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _targetAmount > 0 ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 4: Definir prazo (opcional)
  Widget _buildStep4Deadline() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quando você quer alcançar?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Definir um prazo é opcional, mas ajuda a manter o foco',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          // Opções de prazo
          ...[ 
            {'label': '📅 1 mês', 'months': 1},
            {'label': '📅 3 meses', 'months': 3},
            {'label': '📅 6 meses', 'months': 6},
            {'label': '📅 1 ano', 'months': 12},
          ].map((option) {
            final months = option['months'] as int;
            final deadline = DateTime.now().add(Duration(days: months * 30));
            final isSelected = _deadline != null && 
                _deadline!.year == deadline.year && 
                _deadline!.month == deadline.month;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: isSelected ? AppColors.primary.withOpacity(0.2) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _deadline = deadline),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey[800]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(option['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        const Spacer(),
                        if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          
          const SizedBox(height: 16),
          
          // Data personalizada
          Material(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Row(
                  children: [
                    const Text('📆 Escolher data personalizada', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const Spacer(),
                    if (_deadline != null)
                      Text(DateFormat('dd/MM/yyyy').format(_deadline!), style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Botões finais
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Criar meta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              if (_deadline == null)
                TextButton(
                  onPressed: _isCreating ? null : _createGoal,
                  child: const Text('Continuar sem prazo', style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
