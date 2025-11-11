/// Modelo para formulário de criação/edição de categoria
class CategoryFormModel {
  final String? id;
  final String name;
  final String type; // 'INCOME' ou 'EXPENSE'
  final String color; // Hex color (#RRGGBB)
  final String? group;
  final String? icon;

  const CategoryFormModel({
    this.id,
    required this.name,
    required this.type,
    required this.color,
    this.group,
    this.icon,
  });

  /// Cria um formulário vazio (para criar nova categoria)
  factory CategoryFormModel.empty(String type) {
    return CategoryFormModel(
      name: '',
      type: type,
      color: '#808080', // Cinza padrão
    );
  }

  /// Cria um formulário a partir de uma categoria existente
  factory CategoryFormModel.fromCategory(Map<String, dynamic> category) {
    return CategoryFormModel(
      id: category['id']?.toString(),
      name: category['name']?.toString() ?? '',
      type: category['type']?.toString() ?? 'EXPENSE',
      color: category['color']?.toString() ?? '#808080',
      group: category['group']?.toString(),
      icon: category['icon']?.toString(),
    );
  }

  /// Converte para JSON para enviar ao backend
  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'type': type,
      'color': color.toUpperCase(),
      if (group != null && group!.isNotEmpty) 'group': group,
      if (icon != null && icon!.isNotEmpty) 'icon': icon,
    };
  }

  /// Cria uma cópia com campos alterados
  CategoryFormModel copyWith({
    String? id,
    String? name,
    String? type,
    String? color,
    String? group,
    String? icon,
  }) {
    return CategoryFormModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      group: group ?? this.group,
      icon: icon ?? this.icon,
    );
  }

  /// Validação do formulário
  String? validateName() {
    if (name.trim().isEmpty) {
      return 'Nome é obrigatório';
    }
    if (name.length > 100) {
      return 'Nome deve ter no máximo 100 caracteres';
    }
    return null;
  }

  String? validateColor() {
    final hexRegex = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$');
    if (!hexRegex.hasMatch(color)) {
      return 'Cor deve estar no formato #RRGGBB';
    }
    return null;
  }

  bool get isValid {
    return validateName() == null && validateColor() == null;
  }
}
