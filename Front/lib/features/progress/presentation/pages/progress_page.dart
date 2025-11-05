import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/category.dart';
import '../../../../core/models/goal.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/repositories/finance_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/state/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import 'goal_details_page.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _repository = FinanceRepository();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _cacheManager = CacheManager();
  late Future<List<GoalModel>> _future = _repository.fetchGoals();

  @override
  void initState() {
    super.initState();
    _cacheManager.addListener(_onCacheInvalidated);
  }

  @override
  void dispose() {
    _cacheManager.removeListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    if (_cacheManager.isInvalidated(CacheType.progress)) {
      _refresh();
      _cacheManager.clearInvalidation(CacheType.progress);
    }
  }

  /// Parse seguro de cor hexadecimal
  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Colors.grey;
    }
    
    try {
      // Remove # se existir
      final hex = colorHex.replaceAll('#', '');
      
      // Valida se é hexadecimal válido
      if (hex.length != 6) {
        return Colors.grey;
      }
      
      return Color(int.parse('0xFF$hex', radix: 16));
    } catch (e) {
      // Em caso de erro, retorna cor padrão
      return Colors.grey;
    }
  }

  Future<void> _refresh() async {
    final data = await _repository.fetchGoals();
    if (!mounted) return;
    
    // Atualiza o estado DEPOIS de todo trabalho assíncrono
    if (mounted) {
      setState(() {
        _future = Future.value(data);
      });
    }
  }

  Future<void> _openGoalDialog({GoalModel? goal}) async {
    final titleController = TextEditingController(text: goal?.title ?? '');
    final descriptionController =
        TextEditingController(text: goal?.description ?? '');
    final targetController = TextEditingController(
      text: goal != null ? CurrencyInputFormatter.format(goal.targetAmount) : '',
    );
    final initialAmountController = TextEditingController(
      text: goal != null && goal.initialAmount > 0 
          ? CurrencyInputFormatter.format(goal.initialAmount) 
          : '',
    );
    
    // Novos controladores
    GoalType selectedGoalType = goal?.goalType ?? GoalType.custom;
    int? selectedCategoryId = goal?.targetCategory;
    Set<int> selectedTrackedCategoryIds = goal?.trackedCategories
            .map((cat) => cat.id)
            .toSet() ?? {};
    bool autoUpdate = goal?.autoUpdate ?? false;
    TrackingPeriod trackingPeriod = goal?.trackingPeriod ?? TrackingPeriod.total;
    bool isReductionGoal = goal?.isReductionGoal ?? false;
    DateTime? deadline = goal?.deadline;
    bool isLoading = false;
    
    // Buscar categorias disponíveis
    List<CategoryModel> categories = [];
    try {
      categories = await _repository.fetchCategories();
    } catch (e) {
      // Ignora erro
    }
    
    // Função para filtrar categorias com base no tipo de meta
    List<CategoryModel> getFilteredCategories(GoalType goalType) {
      // CUSTOM: mostra todas as categorias
      if (goalType == GoalType.custom) {
        return categories;
      }
      
      // SAVINGS: apenas categorias de receita (INCOME) e categorias criadas pelo usuário
      if (goalType == GoalType.savings) {
        return categories.where((cat) {
          return cat.type == 'INCOME' || cat.isUserCreated;
        }).toList();
      }
      
      // DEBT_REDUCTION: apenas categorias de dívida (DEBT) e categorias criadas pelo usuário
      if (goalType == GoalType.debtReduction) {
        return categories.where((cat) {
          return cat.type == 'DEBT' || cat.isUserCreated;
        }).toList();
      }
      
      // CATEGORY_EXPENSE: apenas categorias de despesa (EXPENSE)
      if (goalType == GoalType.categoryExpense) {
        return categories.where((cat) => cat.type == 'EXPENSE').toList();
      }
      
      // CATEGORY_INCOME: apenas categorias de receita (INCOME)
      if (goalType == GoalType.categoryIncome) {
        return categories.where((cat) => cat.type == 'INCOME').toList();
      }
      
      return categories;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Verifica se precisa de categoria única (CATEGORY_EXPENSE/INCOME)
          final needsSingleCategory = selectedGoalType == GoalType.categoryExpense ||
              selectedGoalType == GoalType.categoryIncome;
          
          // Verifica se permite múltiplas categorias (SAVINGS/DEBT_REDUCTION)
          final allowsMultipleCategories = selectedGoalType == GoalType.savings ||
              selectedGoalType == GoalType.debtReduction;
          
          // Automaticamente define isReductionGoal para CATEGORY_EXPENSE
          if (selectedGoalType == GoalType.categoryExpense && !isReductionGoal) {
            isReductionGoal = true;
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    goal == null ? Icons.add_circle_outline : Icons.edit_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goal == null ? 'Nova Meta' : 'Editar Meta',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seletor de Tipo de Meta
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
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[700]!,
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<GoalType>(
                        value: selectedGoalType,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E1E1E),
                        icon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                        ),
                        onChanged: isLoading ? null : (value) {
                          setState(() {
                            selectedGoalType = value!;
                            // Limpar categorias quando mudar de tipo
                            if (!needsSingleCategory) {
                              selectedCategoryId = null;
                            }
                            if (!allowsMultipleCategories) {
                              selectedTrackedCategoryIds.clear();
                            }
                          });
                        },
                        items: GoalType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    type.icon,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    type.label,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Seletor de Categoria Única (para CATEGORY_EXPENSE/INCOME)
                  if (needsSingleCategory) ...[
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
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedCategoryId,
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
                          onChanged: isLoading ? null : (value) {
                            setState(() => selectedCategoryId = value);
                          },
                          items: getFilteredCategories(selectedGoalType).map<DropdownMenuItem<int>>((cat) {
                            return DropdownMenuItem<int>(
                              value: cat.id,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Seletor de Múltiplas Categorias (para SAVINGS/DEBT_REDUCTION com auto_update)
                  if (allowsMultipleCategories && autoUpdate) ...[
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
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: getFilteredCategories(selectedGoalType).map((cat) {
                          final isSelected = selectedTrackedCategoryIds.contains(cat.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                if (value == true) {
                                  selectedTrackedCategoryIds.add(cat.id);
                                } else {
                                  selectedTrackedCategoryIds.remove(cat.id);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _parseColor(cat.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            tileColor: isSelected 
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Título
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Título',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
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
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Descrição
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Descrição (opcional)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
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
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Valor Alvo
                  TextField(
                    controller: targetController,
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
                      fillColor: Colors.black.withValues(alpha: 0.3),
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
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Valor Inicial (Opcional)
                  TextField(
                    controller: initialAmountController,
                    enabled: !autoUpdate,
                    style: TextStyle(
                      color: autoUpdate ? Colors.grey[600] : Colors.white,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(maxDigits: 12),
                    ],
                    decoration: InputDecoration(
                      labelText: autoUpdate 
                          ? 'Valor inicial (preenchido automaticamente)' 
                          : 'Valor inicial (opcional)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      hintText: autoUpdate 
                          ? 'Será calculado automaticamente' 
                          : 'Transações antes da criação da meta',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                      prefixText: 'R\$ ',
                      prefixStyle: TextStyle(
                        color: autoUpdate ? Colors.grey[600] : Colors.white,
                      ),
                      filled: true,
                      fillColor: autoUpdate 
                          ? Colors.grey[900]!.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.3),
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
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Toggle de Atualização Automática
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          autoUpdate ? Icons.sync : Icons.sync_disabled,
                          color: autoUpdate ? AppColors.support : Colors.grey[500],
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
                                autoUpdate
                                    ? 'Progresso atualizado com transações'
                                    : 'Controle manual do progresso',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: autoUpdate,
                          onChanged: selectedGoalType == GoalType.custom
                              ? null
                              : (value) {
                                  setState(() => autoUpdate = value);
                                },
                          activeColor: AppColors.support,
                        ),
                      ],
                    ),
                  ),
                  
                  // Período de Tracking (se auto_update ativado)
                  if (autoUpdate && (needsSingleCategory || allowsMultipleCategories)) ...[
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
                        final isSelected = trackingPeriod == period;
                        return ChoiceChip(
                          label: Text(period.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => trackingPeriod = period);
                            }
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.3),
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
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
                  
                  const SizedBox(height: 16),
                  
                  // Prazo
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            deadline == null
                                ? 'Sem prazo definido'
                                : 'Prazo: ${DateFormat('dd/MM/yyyy').format(deadline!)}',
                            style: TextStyle(
                              color: deadline == null ? Colors.grey[500] : Colors.white,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: deadline ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2035),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: AppColors.primary,
                                      surface: const Color(0xFF1E1E1E),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() => deadline = picked);
                            }
                          },
                          child: Text(
                            deadline == null ? 'Definir' : 'Alterar',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        // Validações
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Título é obrigatório'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        final target = CurrencyInputFormatter.parse(targetController.text);
                        
                        if (target <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Valor alvo deve ser maior que zero'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        // Validar categoria obrigatória
                        if (needsSingleCategory && selectedCategoryId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Selecione uma categoria para este tipo de meta'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        Navigator.pop(context, true);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final target = CurrencyInputFormatter.parse(targetController.text);
    final initialAmount = CurrencyInputFormatter.parse(initialAmountController.text);

    setState(() => isLoading = true);

    try {
      if (goal == null) {
        await _repository.createGoal(
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          targetAmount: target,
          initialAmount: initialAmount,
          deadline: deadline,
          goalType: selectedGoalType.value,
          targetCategoryId: selectedCategoryId,
          trackedCategoryIds: selectedTrackedCategoryIds.isNotEmpty 
              ? selectedTrackedCategoryIds.toList()
              : null,
          autoUpdate: autoUpdate,
          trackingPeriod: trackingPeriod.value,
          isReductionGoal: isReductionGoal,
        );
      } else {
        await _repository.updateGoal(
          goalId: goal.id,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          targetAmount: target,
          initialAmount: initialAmount,
          deadline: deadline,
          goalType: selectedGoalType.value,
          targetCategoryId: selectedCategoryId,
          trackedCategoryIds: selectedTrackedCategoryIds.isNotEmpty 
              ? selectedTrackedCategoryIds.toList()
              : null,
          autoUpdate: autoUpdate,
          trackingPeriod: trackingPeriod.value,
          isReductionGoal: isReductionGoal,
        );
      }
      
      if (!mounted) return;
      
      // Invalida cache após criar/editar meta
      _cacheManager.invalidateAfterGoalUpdate();
      
      // Feedback de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(goal == null ? 'Meta criada com sucesso!' : 'Meta atualizada!'),
              ),
            ],
          ),
          backgroundColor: AppColors.support,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Erro ao salvar meta: $e'),
              ),
            ],
          ),
          backgroundColor: AppColors.alert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteGoal(GoalModel goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remover meta', style: TextStyle(color: Colors.white)),
        content: Text(
          'Tem certeza que quer remover "${goal.title}"?',
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
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.deleteGoal(goal.id);
      if (!mounted) return;
      
      // Invalida cache após deletar meta
      _cacheManager.invalidateAfterGoalUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Metas',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'progressFab',
        onPressed: () => _openGoalDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Meta'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: FutureBuilder<List<GoalModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Não foi possível carregar as metas.',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                );
              }

              final goals = snapshot.data ?? [];

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  Text(
                    'Defina e acompanhe suas metas financeiras. Configure valores e prazos para manter o foco nos seus objetivos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (profile != null)
                    _ProfileTargetsCard(profile: profile, currency: _currency),
                  if (profile != null) const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Minhas Metas',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${goals.length} ${goals.length == 1 ? 'meta' : 'metas'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (goals.isEmpty)
                    const _EmptyState(
                      message:
                          'Sem metas cadastradas ainda.\nCrie uma nova meta com o botão abaixo!',
                    )
                  else
                    ...goals.map(
                      (goal) => _GoalCard(
                        goal: goal,
                        currency: _currency,
                        onEdit: () => _openGoalDialog(goal: goal),
                        onDelete: () => _deleteGoal(goal),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileTargetsCard extends StatefulWidget {
  const _ProfileTargetsCard({required this.profile, required this.currency});

  final ProfileModel profile;
  final NumberFormat currency;

  @override
  State<_ProfileTargetsCard> createState() => _ProfileTargetsCardState();
}

class _ProfileTargetsCardState extends State<_ProfileTargetsCard> {
  final _repository = FinanceRepository();
  
  String _calculateIdealTps(double currentTps) {
    if (currentTps < 20) {
      return '≥ 20%';
    } else {
      return '≥ 20%';
    }
  }
  
  String _calculateIdealRdr(double currentRdr) {
    return '< 35%';
  }
  
  String _calculateIdealIli(double currentIli) {
    return '≥ 6m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    
    final progressToNextLevel = widget.profile.experiencePoints / widget.profile.nextLevelThreshold;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: tokens.cardRadius,
        boxShadow: tokens.deepShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresso Geral',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Nível ${widget.profile.level}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressToNextLevel,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${widget.profile.experiencePoints} / ${widget.profile.nextLevelThreshold} XP',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Text(
            'Indicadores Alvo',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Busca dinâmica dos valores reais
          FutureBuilder(
            future: _repository.fetchDashboard(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              }
              
              // Valores padrão se não houver dados
              double tpsCurrent = 0;
              double rdrCurrent = 0;
              double iliCurrent = 0;
              
              if (snapshot.hasData) {
                final summary = snapshot.data!.summary;
                tpsCurrent = summary.tps;
                rdrCurrent = summary.rdr;
                iliCurrent = summary.ili;
              }
              
              return Row(
                children: [
                  Expanded(
                    child: _TargetBadge(
                      label: 'TPS',
                      currentValue: '${tpsCurrent.toStringAsFixed(0)}%',
                      idealRange: _calculateIdealTps(tpsCurrent),
                      icon: Icons.savings_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TargetBadge(
                      label: 'RDR',
                      currentValue: '${rdrCurrent.toStringAsFixed(0)}%',
                      idealRange: _calculateIdealRdr(rdrCurrent),
                      icon: Icons.pie_chart_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TargetBadge(
                      label: 'ILI',
                      currentValue: '${iliCurrent.toStringAsFixed(1)}m',
                      idealRange: _calculateIdealIli(iliCurrent),
                      icon: Icons.health_and_safety_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TargetBadge extends StatelessWidget {
  const _TargetBadge({
    required this.label,
    required this.currentValue,
    required this.idealRange,
    required this.icon,
  });

  final String label;
  final String currentValue;
  final String idealRange;
  final IconData icon;

  void _showExplanationDialog(BuildContext context) {
    String title = '';
    String formula = '';
    String explanation = '';
    String example = '';
    Color color = AppColors.primary;

    if (label == 'TPS') {
      title = 'Taxa de Poupança Pessoal (TPS)';
      formula = 'TPS = (Receitas - Despesas - Pagamentos Dívidas) / Receitas × 100';
      explanation = 'A TPS mede quanto % da sua renda você consegue poupar efetivamente. '
          'É calculada dividindo o valor que sobrou (receitas menos todas as despesas e pagamentos de dívidas) '
          'pelo total de receitas, multiplicado por 100.\n\n'
          'Faixas de referência:\n'
          '• ≥20%: Excelente! Alta capacidade de formar patrimônio\n'
          '• 10-19%: Boa disciplina financeira\n'
          '• <10%: Precisa ajustar o orçamento';
      example = 'Exemplo prático:\n'
          'Receitas: R\$ 5.000\n'
          'Despesas: R\$ 2.000\n'
          'Pagamento dívidas: R\$ 1.500\n'
          'Sobrou: R\$ 1.500\n'
          'TPS = 1.500 / 5.000 × 100 = 30% ✅\n\n'
          'Seu valor atual: $currentValue\n'
          'Faixa ideal: $idealRange';
      color = const Color(0xFF4CAF50);
    } else if (label == 'RDR') {
      title = 'Razão Dívida/Renda (RDR)';
      formula = 'RDR = Pagamentos Mensais Dívidas / Receitas × 100';
      explanation = 'A RDR indica quanto % da sua renda está comprometida com pagamentos mensais de dívidas. '
          'É calculada dividindo o total de pagamentos de dívidas (financiamentos, cartão, empréstimos) '
          'pelo total de receitas, multiplicado por 100.\n\n'
          'Faixas de segurança (padrão bancário):\n'
          '• ≤35%: Saudável - boa margem de segurança\n'
          '• 36-42%: Atenção - começando a apertar o orçamento\n'
          '• ≥43%: Crítico - alto risco de inadimplência';
      example = 'Exemplo prático:\n'
          'Receitas: R\$ 5.000\n'
          'Financiamento carro: R\$ 1.200\n'
          'Cartão crédito: R\$ 800\n'
          'Total dívidas: R\$ 2.000\n'
          'RDR = 2.000 / 5.000 × 100 = 40% ⚠️\n'
          '(Na faixa de atenção)\n\n'
          'Seu valor atual: $currentValue\n'
          'Faixa ideal: $idealRange';
      color = const Color(0xFFFF9800);
    } else if (label == 'ILI') {
      title = 'Índice de Liquidez Imediata (ILI)';
      formula = 'ILI = Reserva Emergência / Despesas Essenciais Mensais';
      explanation = 'O ILI mostra quantos meses sua reserva de emergência consegue cobrir suas despesas essenciais. '
          'É calculado dividindo o saldo da reserva pela média mensal de despesas essenciais dos últimos 3 meses. '
          'Indica sua capacidade de sobreviver financeiramente sem renda.\n\n'
          'Níveis de segurança:\n'
          '• ≥6 meses: Excelente! Você está bem protegido\n'
          '• 3-5 meses: Razoável, mas precisa fortalecer\n'
          '• <3 meses: Crítico - vulnerável a emergências';
      example = 'Exemplo prático:\n'
          'Reserva: R\$ 12.000\n'
          'Despesas essenciais: R\$ 2.000/mês\n'
          'ILI = 12.000 / 2.000 = 6 meses ✅\n\n'
          'Se perder a renda, consegue se manter por 6 meses.\n\n'
          'Seu valor atual: $currentValue\n'
          'Faixa ideal: $idealRange';
      color = const Color(0xFF2196F3);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Valores
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Valor Atual:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[400],
                              ),
                        ),
                        Text(
                          currentValue,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Faixa Ideal:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[400],
                              ),
                        ),
                        Text(
                          idealRange,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Fórmula
              Text(
                'Cálculo:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formula,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Explicação
              Text(
                'O que significa?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                explanation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[300],
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              
              // Exemplo
              Text(
                'Exemplo:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  example,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Entendi',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showExplanationDialog(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 6),
              Text(
                currentValue,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                idealRange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalModel goal;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = goal.progressPercentage.clamp(0, 100);
    final tokens = theme.extension<AppDecorations>()!;
    final isCompleted = goal.isCompleted;
    final isExpired = goal.isExpired;
    
    // Calcular dias restantes
    String? deadlineInfo;
    Color? deadlineColor;
    if (goal.deadline != null) {
      final daysRemaining = goal.daysRemaining!;
      if (daysRemaining < 0) {
        deadlineInfo = 'Prazo expirado';
        deadlineColor = AppColors.alert;
      } else if (daysRemaining == 0) {
        deadlineInfo = 'Último dia';
        deadlineColor = AppColors.alert;
      } else if (daysRemaining <= 7) {
        deadlineInfo = '$daysRemaining dias restantes';
        deadlineColor = const Color(0xFFFF9800);
      } else {
        deadlineInfo = DateFormat('dd/MM/yyyy').format(goal.deadline!);
        deadlineColor = Colors.grey[400];
      }
    }

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailsPage(
              goal: goal,
              currency: currency,
              onEdit: onEdit,
            ),
          ),
        );
        // Se retornou true, significa que houve alteração
        if (result == true && context.mounted) {
          // Recarrega a página principal
          (context.findAncestorStateOfType<_ProgressPageState>())?._refresh();
        }
      },
      borderRadius: tokens.cardRadius,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: tokens.cardRadius,
          boxShadow: tokens.mediumShadow,
          border: isCompleted
              ? Border.all(color: AppColors.support.withValues(alpha: 0.3), width: 1.5)
              : isExpired
                  ? Border.all(color: AppColors.alert.withValues(alpha: 0.3), width: 1.5)
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header com tipo e menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone do tipo de meta
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  goal.goalType.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // Badge do tipo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            goal.goalType.label,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Badge de atualização automática
                        if (goal.autoUpdate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.support.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync, size: 10, color: AppColors.support),
                                const SizedBox(width: 3),
                                Text(
                                  'Auto',
                                  style: TextStyle(
                                    color: AppColors.support,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Badge da categoria (se houver)
                        if (goal.categoryName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              goal.categoryName!,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        // Badge do período (se não for TOTAL)
                        if (goal.trackingPeriod != TrackingPeriod.total)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              goal.trackingPeriod.label,
                              style: const TextStyle(
                                color: Color(0xFFFF9800),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (goal.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        goal.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF2A2A2A),
                icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.grey[300]),
                        const SizedBox(width: 8),
                        Text('Editar', style: TextStyle(color: Colors.grey[300])),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: AppColors.alert),
                        const SizedBox(width: 8),
                        const Text('Remover', style: TextStyle(color: AppColors.alert)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currency.format(goal.currentAmount),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'de ${currency.format(goal.targetAmount)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(
                isCompleted ? AppColors.support : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.trending_up,
                    color: isCompleted ? AppColors.support : AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${progressPercent.toStringAsFixed(1)}% concluído',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCompleted ? AppColors.support : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (deadlineInfo != null)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: deadlineColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deadlineInfo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: deadlineColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.support.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.support.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration,
                    color: AppColors.support,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Meta alcançada! Parabéns pelo seu compromisso!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.support,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isExpired) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.alert.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.alert.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.alert,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prazo expirado. Considere ajustar sua meta ou criar uma nova.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.alert,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppDecorations>()!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: tokens.cardRadius,
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
