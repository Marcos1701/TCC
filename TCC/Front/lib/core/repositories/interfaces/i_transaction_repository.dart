import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/transaction_link.dart';

abstract class ITransactionRepository {
  Future<List<TransactionModel>> fetchTransactions({
    String? type,
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, dynamic>> createTransaction({
    required String type,
    required String description,
    required double amount,
    required DateTime date,
    int? categoryId,
    bool isRecurring = false,
    int? recurrenceValue,
    String? recurrenceUnit,
    DateTime? recurrenceEndDate,
  });

  Future<TransactionModel> updateTransaction({
    required String id,
    String? type,
    String? description,
    double? amount,
    DateTime? date,
    int? categoryId,
    bool? isRecurring,
    int? recurrenceValue,
    String? recurrenceUnit,
    DateTime? recurrenceEndDate,
  });

  Future<void> deleteTransaction(String id);

  Future<Map<String, dynamic>> fetchTransactionDetails(String id);

  Future<List<TransactionModel>> fetchAvailableIncomes({double? minAmount});

  Future<List<TransactionModel>> fetchAvailableExpenses({double? maxAmount});

  Future<Map<String, dynamic>> createTransactionLink({
    required String sourceId,
    required String targetId,
    required double amount,
    String? description,
  });

  Future<void> deleteTransactionLink(String linkId);

  Future<Map<String, dynamic>> createBulkPayment({
    required List<Map<String, dynamic>> payments,
    String description = 'Pagamento em lote',
  });

  Future<Map<String, dynamic>> fetchPaymentReport({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  });

  Future<Map<String, dynamic>> fetchPendingSummary({
    double minRemaining = 0.01,
    String sortBy = 'urgency',
  });

  Future<List<CategoryModel>> fetchCategories({String? type});

  Future<List<TransactionLinkModel>> fetchTransactionLinks({
    String? linkType,
    String? dateFrom,
    String? dateTo,
  });
}
