import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/models/goal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';

/// Resultado do diálogo de edição de meta.
class GoalDialogResult {
  const GoalDialogResult({
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.initialAmount,
    required this.deadline,
    required this.goalType,
    required this.targetCategoryId,
    required this.trackedCategoryIds,
    required this.autoUpdate,
    required this.trackingPeriod,
    required this.isReductionGoal,
  });

  final String title;
  final String description;
  final double targetAmount;
  final double initialAmount;
  final DateTime? deadline;
  final GoalType goalType;
  final int? targetCategoryId;
  final List<int>? trackedCategoryIds;
  final bool autoUpdate;
  final TrackingPeriod trackingPeriod;
  final bool isReductionGoal;
}

/// Diálogo para criar ou editar uma meta.
class GoalEditDialog extends StatefulWidget {
  const GoalEditDialog({
    super.key,
    this.goal,
    required this.categories,
    required this.parseColor,
  });

  final GoalModel? goal;
  final List<CategoryModel> categories;
  final Color Function(String?) parseColor;

  @override
  State<GoalEditDialog> createState() => _GoalEditDialogState();

  /// Abre o diálogo e retorna o resultado ou null se cancelado.
  static Future<GoalDialogResult?> show({
    required BuildContext context,
    GoalModel? goal,
    required List<CategoryModel> categories,
    required Color Function(String?) parseColor,
  }) {
    return showDialog<GoalDialogResult>(
      context: context,
      builder: (context) => GoalEditDialog(
        goal: goal,
        categories: categories,
        parseColor: parseColor,
      ),
    );
  }
}

class _GoalEditDialogState extends State<GoalEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late final TextEditingController _initialAmountController;

  late GoalType _selectedGoalType;
  int? _selectedCategoryId;
  late Set<int> _selectedTrackedCategoryIds;
  late bool _autoUpdate;
  late TrackingPeriod _trackingPeriod;
  late bool _isReductionGoal;
  DateTime? _deadline;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;

    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(text: goal?.description ?? '');
    _targetController = TextEditingController(
      text: goal != null ? CurrencyInputFormatter.format(goal.targetAmount) : '',
    );
    _initialAmountController = TextEditingController(
      text: goal != null && goal.initialAmount > 0
          ? CurrencyInputFormatter.format(goal.initialAmount)
          : '',
    );

    _selectedGoalType = goal?.goalType ?? GoalType.custom;
    _selectedCategoryId = goal?.targetCategory;
    _selectedTrackedCategoryIds =
        goal?.trackedCategories.map((cat) => cat.id).toSet() ?? {};
    _autoUpdate = goal?.autoUpdate ?? false;
    _trackingPeriod = goal?.trackingPeriod ?? TrackingPeriod.total;
    _isReductionGoal = goal?.isReductionGoal ?? false;
    _deadline = goal?.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _initialAmountController.dispose();
    super.dispose();
  }

  bool get _needsSingleCategory =>
      _selectedGoalType == GoalType.categoryExpense ||
      _selectedGoalType == GoalType.categoryIncome;

  bool get _allowsMultipleCategories => _selectedGoalType == GoalType.savings;

  List<CategoryModel> get _filteredCategories {
    if (_selectedGoalType == GoalType.custom) {
      return widget.categories;
    }
    if (_selectedGoalType == GoalType.savings) {
      return widget.categories
          .where((cat) => cat.type == 'INCOME' || cat.isUserCreated)
          .toList();
    }
    if (_selectedGoalType == GoalType.categoryExpense) {
      return widget.categories.where((cat) => cat.type == 'EXPENSE').toList();
    }
    if (_selectedGoalType == GoalType.categoryIncome) {
      return widget.categories.where((cat) => cat.type == 'INCOME').toList();
    }
    return widget.categories;
  }

  void _onGoalTypeChanged(GoalType? value) {
    if (value == null) return;
    setState(() {
      _selectedGoalType = value;
      if (!_needsSingleCategory) {
        _selectedCategoryId = null;
      }
      if (!_allowsMultipleCategories) {
        _selectedTrackedCategoryIds.clear();
      }
      if (_selectedGoalType == GoalType.categoryExpense && !_isReductionGoal) {
        _isReductionGoal = true;
      }
    });
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

    if (_needsSingleCategory && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma categoria para este tipo de meta'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final initialAmount =
        CurrencyInputFormatter.parse(_initialAmountController.text);

    Navigator.pop(
      context,
      GoalDialogResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        targetAmount: target,
        initialAmount: initialAmount,
        deadline: _deadline,
        goalType: _selectedGoalType,
        targetCategoryId: _selectedCategoryId,
        trackedCategoryIds: _selectedTrackedCategoryIds.isNotEmpty
            ? _selectedTrackedCategoryIds.toList()
            : null,
        autoUpdate: _autoUpdate,
        trackingPeriod: _trackingPeriod,
        isReductionGoal: _isReductionGoal,
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
            if (_needsSingleCategory) _buildCategorySelector(),
            if (_allowsMultipleCategories && _autoUpdate)
              _buildMultipleCategoriesSelector(),
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildTargetField(),
            const SizedBox(height: 16),
            _buildInitialAmountField(),
            const SizedBox(height: 20),
            _buildAutoUpdateToggle(),
            if (_autoUpdate && (_needsSingleCategory || _allowsMultipleCategories))
              _buildTrackingPeriodSelector(),
            const SizedBox(height: 16),
            _buildDeadlineSelector(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Salvar',
                  style: TextStyle(fontWeight: FontWeight.w600)),
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
            widget.goal == null ? Icons.add_circle_outline : Icons.edit_outlined,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.goal == null ? 'Nova Meta' : 'Editar Meta',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Meta',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<GoalType>(
              value: _selectedGoalType,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
              ),
              onChanged: _isLoading ? null : _onGoalTypeChanged,
              items: GoalType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(type.icon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(type.label,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoria',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedCategoryId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Selecione uma categoria',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
              ),
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _selectedCategoryId = value),
              items: _filteredCategories.map<DropdownMenuItem<int>>((cat) {
                return DropdownMenuItem<int>(
                  value: cat.id,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(cat.name,
                        style: const TextStyle(color: Colors.white)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMultipleCategoriesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categorias Monitoradas (Opcional)',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Deixe vazio para monitorar todas as categorias padrão',
          style: TextStyle(color: Colors.grey[500], fontSize: 10),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _filteredCategories.map((cat) {
              final isSelected = _selectedTrackedCategoryIds.contains(cat.id);
              return CheckboxListTile(
                value: isSelected,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          if (value == true) {
                            _selectedTrackedCategoryIds.add(cat.id);
                          } else {
                            _selectedTrackedCategoryIds.remove(cat.id);
                          }
                        });
                      },
                title: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.parseColor(cat.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                activeColor: AppColors.primary,
                checkColor: Colors.white,
                tileColor: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Título',
        labelStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
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
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        CurrencyInputFormatter(maxDigits: 12),
      ],
      decoration: InputDecoration(
        labelText: 'Valor alvo',
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixText: 'R\$ ',
        prefixStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
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
      enabled: !_autoUpdate,
      style: TextStyle(color: _autoUpdate ? Colors.grey[600] : Colors.white),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        CurrencyInputFormatter(maxDigits: 12),
      ],
      decoration: InputDecoration(
        labelText: _autoUpdate
            ? 'Valor inicial (preenchido automaticamente)'
            : 'Valor inicial (opcional)',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: _autoUpdate
            ? 'Será calculado automaticamente'
            : 'Transações antes da criação da meta',
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        prefixText: 'R\$ ',
        prefixStyle:
            TextStyle(color: _autoUpdate ? Colors.grey[600] : Colors.white),
        filled: true,
        fillColor: _autoUpdate
            ? Colors.grey[900]!.withOpacity(0.5)
            : Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildAutoUpdateToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            _autoUpdate ? Icons.sync : Icons.sync_disabled,
            color: _autoUpdate ? AppColors.support : Colors.grey[500],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atualização Automática',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _autoUpdate
                      ? 'Progresso atualizado com transações'
                      : 'Controle manual do progresso',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoUpdate,
            onChanged: _selectedGoalType == GoalType.custom
                ? null
                : (value) => setState(() => _autoUpdate = value),
            activeThumbColor: AppColors.support,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Período de Rastreamento',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: TrackingPeriod.values.map((period) {
            final isSelected = _trackingPeriod == period;
            return ChoiceChip(
              label: Text(period.label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _trackingPeriod = period);
                }
              },
              selectedColor: AppColors.primary.withOpacity(0.3),
              backgroundColor: Colors.black.withOpacity(0.3),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.grey[700]!,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDeadlineSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _deadline == null
                  ? 'Sem prazo definido'
                  : 'Prazo: ${DateFormat('dd/MM/yyyy').format(_deadline!)}',
              style: TextStyle(
                color: _deadline == null ? Colors.grey[500] : Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _deadline ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2035),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: Color(0xFF1E1E1E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _deadline = picked);
              }
            },
            child: Text(
              _deadline == null ? 'Definir' : 'Alterar',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
