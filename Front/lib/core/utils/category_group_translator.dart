/// Helper para traduzir grupos de categorias do inglês para português
class CategoryGroupTranslator {
  static const Map<String, String> _translations = {
    // Despesas essenciais
    'ESSENTIAL_EXPENSE': 'Essencial',
    'HOUSING': 'Moradia',
    'UTILITIES': 'Utilidades',
    'FOOD': 'Alimentação',
    'TRANSPORTATION': 'Transporte',
    'HEALTHCARE': 'Saúde',
    'INSURANCE': 'Seguros',
    
    // Despesas de estilo de vida
    'LIFESTYLE_EXPENSE': 'Estilo de Vida',
    'ENTERTAINMENT': 'Entretenimento',
    'SHOPPING': 'Compras',
    'DINING': 'Restaurantes',
    'TRAVEL': 'Viagens',
    'HOBBIES': 'Hobbies',
    'PERSONAL_CARE': 'Cuidados Pessoais',
    'PETS': 'Pets',
    'GIFTS': 'Presentes',
    
    // Investimentos e poupança
    'SAVINGS': 'Poupança',
    'INVESTMENT': 'Investimentos',
    'EMERGENCY_FUND': 'Reserva de Emergência',
    'RETIREMENT': 'Aposentadoria',
    
    // Receitas
    'INCOME': 'Receita',
    'SALARY': 'Salário',
    'FREELANCE': 'Freelance',
    'BUSINESS': 'Negócio',
    'PASSIVE_INCOME': 'Renda Passiva',
    'GIFT': 'Presente',
    'REFUND': 'Reembolso',
    'OTHER_INCOME': 'Outras Receitas',
    
    // Outros
    'OTHER': 'Outros',
    'UNCATEGORIZED': 'Sem Categoria',
  };

  /// Traduz um grupo de categoria do inglês para português
  static String translate(String? group) {
    if (group == null || group.isEmpty) {
      return 'Outros';
    }
    return _translations[group.toUpperCase()] ?? group;
  }

  /// Retorna a cor associada a um grupo
  static String getGroupColor(String? group) {
    if (group == null) return '#9E9E9E';
    
    final normalizedGroup = group.toUpperCase();
    
    // Essenciais - tons de azul
    if (normalizedGroup.contains('ESSENTIAL') || 
        normalizedGroup.contains('HOUSING') ||
        normalizedGroup.contains('UTILITIES') ||
        normalizedGroup.contains('FOOD')) {
      return '#2196F3';
    }
    
    // Transporte e saúde - tons de verde
    if (normalizedGroup.contains('TRANSPORTATION') ||
        normalizedGroup.contains('HEALTHCARE')) {
      return '#4CAF50';
    }
    
    // Estilo de vida - tons de roxo/rosa
    if (normalizedGroup.contains('LIFESTYLE') ||
        normalizedGroup.contains('ENTERTAINMENT') ||
        normalizedGroup.contains('SHOPPING')) {
      return '#9C27B0';
    }
    
    // Investimentos e poupança - tons de ouro
    if (normalizedGroup.contains('SAVINGS') ||
        normalizedGroup.contains('INVESTMENT') ||
        normalizedGroup.contains('EMERGENCY')) {
      return '#FFC107';
    }
    
    // Receitas - tons de verde escuro
    if (normalizedGroup.contains('INCOME') ||
        normalizedGroup.contains('SALARY') ||
        normalizedGroup.contains('FREELANCE')) {
      return '#4CAF50';
    }
    
    // Default - cinza
    return '#9E9E9E';
  }

  /// Retorna um ícone sugerido para um grupo
  static String getGroupIcon(String? group) {
    if (group == null) return '📦';
    
    final normalizedGroup = group.toUpperCase();
    
    if (normalizedGroup.contains('HOUSING')) return '🏠';
    if (normalizedGroup.contains('UTILITIES')) return '⚡';
    if (normalizedGroup.contains('FOOD')) return '🍽️';
    if (normalizedGroup.contains('TRANSPORTATION')) return '🚗';
    if (normalizedGroup.contains('HEALTHCARE')) return '🏥';
    if (normalizedGroup.contains('INSURANCE')) return '🛡️';
    if (normalizedGroup.contains('ENTERTAINMENT')) return '🎮';
    if (normalizedGroup.contains('SHOPPING')) return '🛍️';
    if (normalizedGroup.contains('DINING')) return '🍴';
    if (normalizedGroup.contains('TRAVEL')) return '✈️';
    if (normalizedGroup.contains('SAVINGS')) return '💰';
    if (normalizedGroup.contains('INVESTMENT')) return '📈';
    if (normalizedGroup.contains('INCOME')) return '💵';
    if (normalizedGroup.contains('SALARY')) return '💼';
    
    return '📦';
  }
}
