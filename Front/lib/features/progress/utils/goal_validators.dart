import '../../../core/models/category.dart';
import '../../../core/models/goal.dart';

/// Validações específicas para metas financeiras
class GoalValidators {
  /// Valida se uma meta de EXPENSE_REDUCTION tem todos os campos necessários
  static String? validateExpenseReduction({
    required CategoryModel? targetCategory,
    required double? baselineAmount,
  }) {
    if (targetCategory == null) {
      return 'Selecione uma categoria alvo para metas de redução de gastos';
    }
    
    if (targetCategory.type != 'EXPENSE') {
      return 'A categoria alvo deve ser de despesas (não de receitas)';
    }
    
    if (baselineAmount == null || baselineAmount <= 0) {
      return 'Informe o gasto médio mensal atual nesta categoria';
    }
    
    return null; // Válido
  }

  /// Valida se uma meta de INCOME_INCREASE tem todos os campos necessários
  static String? validateIncomeIncrease({
    required double? baselineAmount,
  }) {
    if (baselineAmount == null || baselineAmount <= 0) {
      return 'Informe sua receita média mensal atual para comparação';
    }
    
    return null; // Válido
  }

  /// Valida meta baseado no tipo
  static String? validateByType({
    required GoalType goalType,
    CategoryModel? targetCategory,
    double? baselineAmount,
  }) {
    switch (goalType) {
      case GoalType.expenseReduction:
        return validateExpenseReduction(
          targetCategory: targetCategory,
          baselineAmount: baselineAmount,
        );
      
      case GoalType.incomeIncrease:
        return validateIncomeIncrease(baselineAmount: baselineAmount);
      
      default:
        return null; // Outros tipos não precisam validação especial
    }
  }
}
