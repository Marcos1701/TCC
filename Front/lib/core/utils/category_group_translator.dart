class CategoryGroupTranslator {
  static const Map<String, String> _translations = {
    'ESSENTIAL_EXPENSE': 'Essencial',
    'HOUSING': 'Moradia',
    'UTILITIES': 'Utilidades',
    'FOOD': 'Alimentação',
    'TRANSPORTATION': 'Transporte',
    'HEALTHCARE': 'Saúde',
    'INSURANCE': 'Seguros',
    
    'LIFESTYLE_EXPENSE': 'Estilo de Vida',
    'ENTERTAINMENT': 'Entretenimento',
    'SHOPPING': 'Compras',
    'DINING': 'Restaurantes',
    'TRAVEL': 'Viagens',
    'HOBBIES': 'Hobbies',
    'PERSONAL_CARE': 'Cuidados Pessoais',
    'PETS': 'Pets',
    'GIFTS': 'Presentes',
    
    'SAVINGS': 'Poupança',
    'INVESTMENT': 'Investimentos',
    'EMERGENCY_FUND': 'Reserva de Emergência',
    'RETIREMENT': 'Aposentadoria',
    
    'INCOME': 'Receita',
    'SALARY': 'Salário',
    'FREELANCE': 'Freelance',
    'BUSINESS': 'Negócio',
    'PASSIVE_INCOME': 'Renda Passiva',
    'GIFT': 'Presente',
    'REFUND': 'Reembolso',
    'OTHER_INCOME': 'Outras Receitas',
    
    'OTHER': 'Outros',
    'UNCATEGORIZED': 'Sem Categoria',
  };

  static String translate(String? group) {
    if (group == null || group.isEmpty) {
      return 'Outros';
    }
    return _translations[group.toUpperCase()] ?? group;
  }

  static String getGroupColor(String? group) {
    if (group == null) return '#9E9E9E';
    
    final normalizedGroup = group.toUpperCase();
    
    if (normalizedGroup.contains('ESSENTIAL') || 
        normalizedGroup.contains('HOUSING') ||
        normalizedGroup.contains('UTILITIES') ||
        normalizedGroup.contains('FOOD')) {
      return '#2196F3';
    }
    
    if (normalizedGroup.contains('TRANSPORTATION') ||
        normalizedGroup.contains('HEALTHCARE')) {
      return '#4CAF50';
    }
    
    if (normalizedGroup.contains('LIFESTYLE') ||
        normalizedGroup.contains('ENTERTAINMENT') ||
        normalizedGroup.contains('SHOPPING')) {
      return '#9C27B0';
    }
    
    if (normalizedGroup.contains('SAVINGS') ||
        normalizedGroup.contains('INVESTMENT') ||
        normalizedGroup.contains('EMERGENCY')) {
      return '#FFC107';
    }
    
    if (normalizedGroup.contains('INCOME') ||
        normalizedGroup.contains('SALARY') ||
        normalizedGroup.contains('FREELANCE')) {
      return '#4CAF50';
    }
    
    return '#9E9E9E';
  }

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
