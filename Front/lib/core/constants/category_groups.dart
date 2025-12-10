class CategoryGroupMetadata {
  const CategoryGroupMetadata._();

  static const Map<String, String> labels = {
    'REGULAR_INCOME': 'Renda principal',
    'EXTRA_INCOME': 'Renda extra',
    'SAVINGS': 'Poupança / Reserva',
    'INVESTMENT': 'Investimentos',
    'ESSENTIAL_EXPENSE': 'Despesas essenciais',
    'LIFESTYLE_EXPENSE': 'Estilo de vida',
    'DEBT': 'Dívidas',
    'GOAL': 'Metas e sonhos',
    'OTHER': 'Outros',
  };

  static const Map<String, List<String>> groupsByType = {
    'INCOME': [
      'REGULAR_INCOME',
      'EXTRA_INCOME',
      'SAVINGS',
      'INVESTMENT',
      'OTHER',
    ],
    'EXPENSE': [
      'ESSENTIAL_EXPENSE',
      'LIFESTYLE_EXPENSE',
      'SAVINGS',
      'INVESTMENT',
      'GOAL',
      'OTHER',
    ],
    'DEBT': [
      'DEBT',
      'GOAL',
      'OTHER',
    ],
  };

  static List<String> groupsForType(String type) {
    return groupsByType[type] ?? const ['OTHER'];
  }
}
