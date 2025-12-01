import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/category.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../utils/goal_validators.dart';
import 'category_selector.dart';
import 'baseline_amount_field.dart';

/// Resultado do diálogo de edição de meta.
class GoalDialogResult {
  /// Cria um resultado do diálogo de edição de meta.
  const GoalDialogResult({
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.initialAmount,
    required this.deadline,
    required this.goalType,
    this.targetCategory,
    this.baselineAmount,
    this.trackingPeriodMonths = 3,
  });

  /// Título da meta.
  final String title;

  /// Descrição da meta.
  final String description;

  /// Valor alvo da meta.
  final double targetAmount;

  /// Valor inicial da meta.
  final double initialAmount;

  /// Prazo da meta.
  final DateTime? deadline;

  /// Tipo da meta.
  final GoalType goalType;

  /// Categoria alvo (para EXPENSE_REDUCTION)
  final String? targetCategory;

  /// Valor de referência inicial (para EXPENSE_REDUCTION e INCOME_INCREASE)
  final double? baselineAmount;

  /// Período de cálculo em meses
  final int trackingPeriodMonths;
}

/// Diálogo para criar ou editar uma meta.
class GoalEditDialog extends StatefulWidget {
  /// Cria um diálogo de edição de meta.
  const GoalEditDialog({
    super.key,
    this.goal,
  });

  /// Meta existente para edição.
  final GoalModel? goal;

  @override
  State<GoalEditDialog> createState() => _GoalEditDialogState();

  /// Abre o diálogo e retorna o resultado ou null se cancelado.
  static Future<GoalDialogResult?> show({
    required BuildContext context,
    GoalModel? goal,
  }) {
    return showDialog<GoalDialogResult>(
      context: context,
      builder: (context) => GoalEditDialog(goal: goal),
    );
  }
}

class _GoalEditDialogState extends State<GoalEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late final TextEditingController _initialAmountController;
  late final TextEditingController _baselineAmountController;

  late GoalType _selectedGoalType;
  DateTime? _deadline;
  CategoryModel? _selectedCategory;
  int _trackingPeriodMonths = 3;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;

    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController =
        TextEditingController(text: goal?.description ?? '');
    _targetController = TextEditingController(
      text: goal != null ? CurrencyInputFormatter.format(goal.targetAmount) : '',
    );
    _initialAmountController = TextEditingController(
      text: goal != null && goal.initialAmount > 0
          ? CurrencyInputFormatter.format(goal.initialAmount)
          : '',
    );
    _baselineAmountController = TextEditingController(
      text: goal != null && goal.baselineAmount != null
          ? CurrencyInputFormatter.format(goal.baselineAmount!)
          : '',
    );

    _selectedGoalType = goal?.goalType ?? GoalType.savings;
    _deadline = goal?.deadline;
    // TODO: Carregar categoria se goal.targetCategory existir
    _trackingPeriodMonths = goal?.trackingPeriodMonths ?? 3;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _initialAmountController.dispose();
    _baselineAmountController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Título é obrigatório'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final target = CurrencyInputFormatter.parse(_targetController.text);
    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valor alvo deve ser maior que zero'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final initialAmount =
        CurrencyInputFormatter.parse(_initialAmountController.text);
    
    // Parse baseline amount se preenchido
    final baselineAmount = _baselineAmountController.text.isNotEmpty
        ? CurrencyInputFormatter.parse(_baselineAmountController.text)
        : null;

    // Validação específica por tipo de meta
    final validationError = GoalValidators.validateByType(
      goalType: _selectedGoalType,
      targetCategory: _selectedCategory,
      baselineAmount: baselineAmount,
    );

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      GoalDialogResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        targetAmount: target,
        initialAmount: initialAmount,
        deadline: _deadline,
        goalType: _selectedGoalType,
        targetCategory: _selectedCategory?.id.toString(),
        baselineAmount: baselineAmount,
        trackingPeriodMonths: _trackingPeriodMonths,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: _buildTitle(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoalTypeSelector(),
            const SizedBox(height: 20),
            
            // CategorySelector - apenas para EXPENSE_REDUCTION
            if (_selectedGoalType == GoalType.expenseReduction) ...[
              Theme(
                data: ThemeData.light(),
                child: CategorySelector(
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) {
                    setState(() => _selectedCategory = category);
                  },
                  label: 'Categoria Alvo',
                  hint: 'Selecione a categoria de gastos',
                  categoryType: 'EXPENSE',
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // BaselineAmountField - para EXPENSE_REDUCTION e INCOME_INCREASE
            if (_selectedGoalType == GoalType.expenseReduction ||
                _selectedGoalType == GoalType.incomeIncrease) ...[
              Theme(
                data: ThemeData.light(),
                child: BaselineAmountField(
                  controller: _baselineAmountController,
                  goalType: _selectedGoalType,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Tracking Period Slider
            if (_selectedGoalType == GoalType.expenseReduction ||
                _selectedGoalType == GoalType.incomeIncrease) ...[
              const Text(
                'Período de Cálculo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _trackingPeriodMonths.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                label: '$_trackingPeriodMonths meses',
                activeColor: AppColors.primary,
                onChanged: (value) {
                  setState(() => _trackingPeriodMonths = value.toInt());
                },
              ),
              Text(
                'Progresso calculado com base nos últimos $_trackingPeriodMonths meses',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildTargetField(),
            const SizedBox(height: 16),
            _buildInitialAmountField(),
            const SizedBox(height: 20),
            _buildDeadlineSelector(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _isEditing ? 'Salvar' : 'Criar',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isEditing ? Icons.edit : Icons.add_circle_outline,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _isEditing ? 'Editar Meta' : 'Nova Meta',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Meta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGoalTypeOption(
                type: GoalType.savings,
                icon: Icons.savings_outlined,
                label: 'Juntar',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGoalTypeOption(
                type: GoalType.custom,
                icon: Icons.edit_outlined,
                label: 'Personalizada',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalTypeOption({
    required GoalType type,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedGoalType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoalType = type;
          // Limpar campos específicos ao mudar tipo
          if (type != GoalType.expenseReduction) {
            _selectedCategory = null;
          }
          if (type != GoalType.expenseReduction && 
              type != GoalType.incomeIncrease) {
            _baselineAmountController.clear();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withOpacity(0.2) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Título',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: 'Ex: Celular novo',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[900],
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      style: const TextStyle(color: Colors.white),
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Descrição (opcional)',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: 'Descreva sua meta',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[900],
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildTargetField() {
    return TextField(
      controller: _targetController,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
        CurrencyInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: 'Valor Alvo',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: 'R\$ 0,00',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[900],
        prefixIcon: Icon(Icons.attach_money, color: Colors.grey[500]),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildInitialAmountField() {
    return TextField(
      controller: _initialAmountController,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
        CurrencyInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: 'Valor Inicial (opcional)',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: 'Quanto você já tem?',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[900],
        prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.grey[500]),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDeadlineSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prazo (opcional)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectDeadline,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[500], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _deadline != null
                        ? DateFormat('dd/MM/yyyy').format(_deadline!)
                        : 'Selecionar data',
                    style: TextStyle(
                      color: _deadline != null ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                    onPressed: () => setState(() => _deadline = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }
}
