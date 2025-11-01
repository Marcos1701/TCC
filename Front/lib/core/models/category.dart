class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.color,
    this.group,
  });

  final int id;
  final String name;
  final String type;
  final String? color;
  final String? group;

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      type: map['type'] as String,
      color: map['color'] as String?,
      group: map['group'] as String?,
    );
  }
}
