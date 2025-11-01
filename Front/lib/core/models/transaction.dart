import 'category.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    this.category,
    this.isRecurring = false,
    this.recurrenceValue,
    this.recurrenceUnit,
    this.recurrenceEndDate,
  });

  final int id;
  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final CategoryModel? category;
  final bool isRecurring;
  final int? recurrenceValue;
  final String? recurrenceUnit;
  final DateTime? recurrenceEndDate;

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
      isRecurring: map['is_recurring'] as bool? ?? false,
    recurrenceValue: map['recurrence_value'] != null
      ? int.tryParse(map['recurrence_value'].toString())
      : null,
      recurrenceUnit: map['recurrence_unit'] as String?,
      recurrenceEndDate: map['recurrence_end_date'] != null
          ? DateTime.tryParse(map['recurrence_end_date'] as String)
          : null,
    );
  }

  String? get recurrenceLabel {
    if (!isRecurring || recurrenceValue == null || recurrenceUnit == null) {
      return null;
    }
    final value = recurrenceValue!;
    switch (recurrenceUnit) {
      case 'DAYS':
        return value == 1 ? 'Repetição diária' : 'A cada $value dias';
      case 'WEEKS':
        return value == 1 ? 'A cada semana' : 'A cada $value semanas';
      case 'MONTHS':
        return value == 1 ? 'A cada mês' : 'A cada $value meses';
      default:
        return 'Recorrência ativa';
    }
  }
}
