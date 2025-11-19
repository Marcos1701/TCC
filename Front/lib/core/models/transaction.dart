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
    this.linkedAmount,
    this.availableAmount,
    this.linkPercentage,
    this.outgoingLinksCount,
    this.incomingLinksCount,
  });

  final String id;
  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final CategoryModel? category;
  final bool isRecurring;
  final int? recurrenceValue;
  final String? recurrenceUnit;
  final DateTime? recurrenceEndDate;
  
  // Campos de vinculação
  final double? linkedAmount;
  final double? availableAmount;
  final double? linkPercentage;
  final int? outgoingLinksCount;
  final int? incomingLinksCount;

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'].toString(),
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
      linkedAmount: map['linked_amount'] != null
          ? double.tryParse(map['linked_amount'].toString())
          : null,
      availableAmount: map['available_amount'] != null
          ? double.tryParse(map['available_amount'].toString())
          : null,
      linkPercentage: map['link_percentage'] != null
          ? double.tryParse(map['link_percentage'].toString())
          : null,
      outgoingLinksCount: map['outgoing_links_count'] != null
          ? int.tryParse(map['outgoing_links_count'].toString())
          : null,
      incomingLinksCount: map['incoming_links_count'] != null
          ? int.tryParse(map['incoming_links_count'].toString())
          : null,
    );
  }
  
  // Helpers para vinculações
  bool get hasLinks => (outgoingLinksCount ?? 0) > 0 || (incomingLinksCount ?? 0) > 0;
  bool get hasAvailableAmount => availableAmount != null && availableAmount! > 0;
  bool get isFullyLinked => linkPercentage != null && linkPercentage! >= 100.0;

  /// Retorna o identificador preferencial
  String get identifier => id;
  
  /// Verifica se possui UUID (sempre true agora)
  bool get hasUuid => true;

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
