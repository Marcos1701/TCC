import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/category.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import 'goal_wizard_components.dart';

/// Wizard simplificado para criação de metas (Dia 15-20)
/// 
/// Fluxo de 5 passos:
/// 1. Objetivo: Tipo (Juntar dinheiro ou Reduzir gastos)
/// 2. Nome: Título com templates ou customizado
/// 3. Categorias: Seleção de categorias monitoradas (apenas CATEGORY_EXPENSE)
/// 4. Valor: Meta financeira
/// 5. Prazo: Data limite (opcional)
/// 
/// Simplificações:
/// - Apenas 2 tipos principais (SAVINGS e CATEGORY_EXPENSE)
/// - Auto-update sempre ativo
/// - Tracking period sempre TOTAL
/// - Templates pré-configurados com sugestões de categorias
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
  List<CategoryModel> _selectedCategories = []; // Múltiplas categorias
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = false;
  bool _isCreating = false;

  // Templates sugeridos por tipo
  final Map<GoalType, List<String>> _templates = {
    GoalType.savings: [
      '📱 Celular novo',
      '✈️ Viagem dos sonhos',
      '🏠 Entrada do apartamento',
      '🚗 Carro próprio',
      '🎓 Curso/Educação',
      '💰 Fundo de emergência',
    ],
    GoalType.categoryExpense: [
      '🍕 Reduzir delivery',
      '💡 Economizar energia',
      '🚗 Reduzir transporte',
      '🛍️ Controlar compras',
      '☕ Menos cafeteria',
      '🎮 Reduzir entretenimento',
    ],
  };

  // Mapeamento de templates → palavras-chave de categoria
  final Map<String, List<String>> _templateCategoryKeywords = {
    '🍕 Reduzir delivery': ['alimentação', 'delivery', 'comida', 'restaurante', 'ifood'],
    '💡 Economizar energia': ['moradia', 'energia', 'luz', 'conta', 'utilities'],
    '🚗 Reduzir transporte': ['transporte', 'uber', 'combustível', 'gasolina', 'ônibus'],
    '🛍️ Controlar compras': ['compras', 'shopping', 'vestuário', 'roupa'],
    '☕ Menos cafeteria': ['alimentação', 'café', 'cafeteria', 'lanche'],
    '🎮 Reduzir entretenimento': ['lazer', 'entretenimento', 'streaming', 'diversão'],
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      _categories = await _repository.fetchCategories(type: 'EXPENSE');
    } catch (e) {
      // Silently fail - categories are optional
    } finally {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!mounted) return;
    if (_currentStep < 4) { // 5 steps: 0-4
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (!mounted) return;
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      
      // Se está voltando para o step 3 (categorias) e o tipo é SAVINGS, pula mais um
      if (_currentStep == 2 && _selectedType == GoalType.savings) {
        setState(() => _currentStep--);
      }
      
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Sugere categorias baseadas no template selecionado
  void _suggestCategoriesForTemplate(String template) {
    final keywords = _templateCategoryKeywords[template];
    if (keywords == null || keywords.isEmpty) return;

    final suggested = <CategoryModel>[];
    for (final category in _categories) {
      for (final keyword in keywords) {
        if (category.name.toLowerCase().contains(keyword.toLowerCase())) {
          if (!suggested.contains(category)) {
            suggested.add(category);
          }
          break;
        }
      }
    }

    setState(() {
      _selectedCategories = suggested;
    });
  }

  Future<void> _createGoal() async {
    if (_isCreating) return;
    
    // Validação: Categoria é obrigatória para CATEGORY_EXPENSE
    if (_selectedType == GoalType.categoryExpense && _selectedCategories.isEmpty) {
      if (mounted) {
        FeedbackService.showError(
          context,
          'Por favor, selecione pelo menos uma categoria para esta meta.',
        );
      }
      return;
    }
    
    setState(() => _isCreating = true);

    try {
      await _repository.createGoal(
        title: _title,
        description: '',
        targetAmount: _targetAmount,
        currentAmount: 0,
        initialAmount: 0,
        deadline: _deadline,
        goalType: _selectedType!.value,
        // Usar tracked_category_ids para múltiplas categorias
        trackedCategoryIds: _selectedCategories.map((c) => c.id).toList(),
        autoUpdate: true, // Sempre ativo para simplificar
        trackingPeriod: TrackingPeriod.total.value,
        isReductionGoal: _selectedType == GoalType.categoryExpense,
      );

      // Rastreia criação de meta via wizard
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
        FeedbackService.showError(
          context,
          'Erro ao criar meta: ${e.toString()}',
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nova Meta'),
        actions: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _previousStep,
              tooltip: 'Voltar',
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Page view com os steps
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1GoalType(),      // 1. Objetivo
                _buildStep2Title(),         // 2. Nome
                _buildStep3Categories(),    // 3. Categorias
                _buildStep4Amount(),        // 4. Valor
                _buildStep5Deadline(),      // 5. Prazo
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(5, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(left: index > 0 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
              child: isCompleted
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }

  // STEP 1: Escolher tipo de meta
  Widget _buildStep1GoalType() {
    return Padding(
      padding: const EdgeInsets.all(24),
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
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          
          // Opção: Juntar dinheiro
          GoalTypeCard(
            icon: Icons.savings_outlined,
            iconColor: Colors.green,
            title: 'Juntar dinheiro',
            description: 'Economizar para um objetivo específico',
            examples: '📱 Celular, ✈️ Viagem, 🏠 Casa própria',
            isSelected: _selectedType == GoalType.savings,
            onTap: () {
              setState(() => _selectedType = GoalType.savings);
              _nextStep();
            },
          ),
          
          const SizedBox(height: 16),
          
          // Opção: Reduzir gastos
          GoalTypeCard(
            icon: Icons.trending_down_outlined,
            iconColor: Colors.orange,
            title: 'Reduzir gastos',
            description: 'Controlar e diminuir despesas',
            examples: '🍕 Delivery, 💡 Energia, 🛍️ Compras',
            isSelected: _selectedType == GoalType.categoryExpense,
            onTap: () {
              setState(() => _selectedType = GoalType.categoryExpense);
              _nextStep();
            },
          ),
        ],
      ),
    );
  }

  // STEP 2: Escolher título (com templates)
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
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
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
            
            // Lista de templates (altura fixa)
            SizedBox(
              height: 250, // Altura fixa para os templates
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
                          // Sugerir categorias automaticamente se for CATEGORY_EXPENSE
                          if (_selectedType == GoalType.categoryExpense) {
                            _suggestCategoriesForTemplate(template);
                          }
                          _nextStep();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[800]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                template,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                ),
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
      ), // Column
      ), // SingleChildScrollView
    );
  }

  // STEP 3: Selecionar categorias (apenas para CATEGORY_EXPENSE)
  Widget _buildStep3Categories() {
    // Se for SAVINGS, não mostra seleção de categorias
    if (_selectedType != GoalType.categoryExpense) {
      // Pula automaticamente para o próximo passo (com proteção)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentStep == 2) {
          _nextStep();
        }
      });
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quais categorias monitorar?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategories.isEmpty
                ? 'Selecione uma ou mais categorias para acompanhar seus gastos'
                : '${_selectedCategories.length} categoria${_selectedCategories.length > 1 ? 's' : ''} selecionada${_selectedCategories.length > 1 ? 's' : ''}',
            style: TextStyle(
              color: _selectedCategories.isEmpty ? Colors.grey[400] : AppColors.primary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // Loading ou lista de categorias
          Expanded(
            child: _isLoadingCategories
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma categoria de despesa encontrada.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((category) {
                            final isSelected = _selectedCategories.contains(category);
                            return FilterChip(
                              selected: isSelected,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (category.color != null)
                                    Container(
                                      width: 12,
                                      height: 12,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(
                                            category.color!.substring(1),
                                            radix: 16) +
                                            0xFF000000),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Text(category.name),
                                ],
                              ),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[300],
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              backgroundColor: const Color(0xFF1E1E1E),
                              selectedColor: AppColors.primary.withOpacity(0.3),
                              checkmarkColor: Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey[800]!,
                                width: isSelected ? 2 : 1,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategories.add(category);
                                  } else {
                                    _selectedCategories.remove(category);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
          ),

          const SizedBox(height: 16),

          // Botão continuar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedCategories.isNotEmpty ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[800],
              ),
              child: Text(
                _selectedCategories.isEmpty
                    ? 'Selecione pelo menos uma categoria'
                    : 'Continuar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _selectedCategories.isEmpty
                      ? Colors.grey[600]
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 4: Definir valor alvo
  Widget _buildStep4Amount() {
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
            _selectedType == GoalType.savings
                ? 'Quanto você quer juntar?'
                : 'Quanto você quer reduzir de gastos?',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
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
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 32,
              ),
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
                setState(() {
                  _targetAmount = double.parse(cleanValue) / 100;
                });
              } else {
                setState(() => _targetAmount = 0);
              }
            },
          ),
          
          const SizedBox(height: 32),
          
          // Sugestões rápidas
          const Text(
            'Sugestões:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 5: Definir prazo (opcional)
  Widget _buildStep5Deadline() {
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
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
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
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : const Color(0xFF1E1E1E),
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
                        Text(
                          option['label'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppColors.primary),
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
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark(),
                      child: child!,
                    );
                  },
                );
                
                if (picked != null) {
                  setState(() => _deadline = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Row(
                  children: [
                    const Text(
                      '📆 Escolher data personalizada',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const Spacer(),
                    if (_deadline != null)
                      Text(
                        DateFormat('dd/MM/yyyy').format(_deadline!),
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Botões finais
          Column(
            children: [
              // Criar meta
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Criar meta',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Sem prazo
              if (_deadline == null)
                TextButton(
                  onPressed: _isCreating ? null : _createGoal,
                  child: const Text(
                    'Continuar sem prazo',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
