import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';

/// Wizard simplificado para criação de metas (Dia 15-20)
/// 
/// Fluxo de 4 passos:
/// 1. Tipo (Juntar dinheiro ou Reduzir gastos)
/// 2. Título/Objetivo (com templates)
/// 3. Valor alvo
/// 4. Prazo (opcional)
/// 
/// Simplificações:
/// - Apenas 2 tipos principais (SAVINGS e CATEGORY_EXPENSE)
/// - Auto-update sempre ativo
/// - Tracking period sempre TOTAL
/// - Templates pré-configurados
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createGoal() async {
    if (_isCreating) return;
    
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
        autoUpdate: true, // Sempre ativo para simplificar
        trackingPeriod: TrackingPeriod.total.value,
        isReductionGoal: _selectedType == GoalType.categoryExpense,
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
                _buildStep1GoalType(),
                _buildStep2Title(),
                _buildStep3Amount(),
                _buildStep4Deadline(),
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
        children: List.generate(4, (index) {
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
          _GoalTypeCard(
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
          _GoalTypeCard(
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
          
          Expanded(
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

/// Card para seleção de tipo de meta
class _GoalTypeCard extends StatelessWidget {
  const _GoalTypeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.examples,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String examples;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected 
          ? AppColors.primary.withOpacity(0.2)
          : const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[800]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      examples,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
