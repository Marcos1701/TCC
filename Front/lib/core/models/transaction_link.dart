import 'transaction.dart';

class TransactionLinkModel {
  const TransactionLinkModel({
    required this.id,
    this.sourceTransaction,
    this.targetTransaction,
    required this.linkedAmount,
    required this.linkType,
    this.description,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final TransactionModel? sourceTransaction;
  final TransactionModel? targetTransaction;
  final double linkedAmount;
  final String linkType;
  final String? description;
  final bool isRecurring;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TransactionLinkModel.fromMap(Map<String, dynamic> map) {
    return TransactionLinkModel(
      id: map['id'] as int,
      sourceTransaction: map['source_transaction'] != null
          ? TransactionModel.fromMap(map['source_transaction'] as Map<String, dynamic>)
          : null,
      targetTransaction: map['target_transaction'] != null
          ? TransactionModel.fromMap(map['target_transaction'] as Map<String, dynamic>)
          : null,
      linkedAmount: double.parse(map['linked_amount'].toString()),
      linkType: map['link_type'] as String,
      description: map['description'] as String?,
      isRecurring: map['is_recurring'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'linked_amount': linkedAmount.toString(),
      'link_type': linkType,
      if (description != null) 'description': description,
      'is_recurring': isRecurring,
    };
  }

  String get linkTypeLabel {
    switch (linkType) {
      case 'DEBT_PAYMENT':
        return 'Pagamento de despesa';
      case 'INTERNAL_TRANSFER':
        return 'Transferência interna';
      case 'SAVINGS_ALLOCATION':
        return 'Alocação para poupança';
      default:
        return 'Vinculação';
    }
  }
}

class CreateTransactionLinkRequest {
  const CreateTransactionLinkRequest({
    required this.sourceId,
    required this.targetId,
    required this.amount,
    this.linkType,
    this.description,
    this.isRecurring,
  });

  final int sourceId;
  final int targetId;
  final double amount;
  final String? linkType;
  final String? description;
  final bool? isRecurring;

  Map<String, dynamic> toMap() {
    return {
      'source_id': sourceId,
      'target_id': targetId,
      'linked_amount': amount.toString(),
      if (linkType != null) 'link_type': linkType,
      if (description != null) 'description': description,
      if (isRecurring != null) 'is_recurring': isRecurring,
    };
  }
}
