import 'category.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    this.category,
  });

  final int id;
  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final CategoryModel? category;

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int,
      type: map['type'] as String,
      description: map['description'] as String,
      amount: double.parse(map['amount'].toString()),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] != null
          ? CategoryModel.fromMap(map['category'] as Map<String, dynamic>)
          : null,
    );
  }
}
