import '../models/transaction.dart';
import '../models/transaction_link.dart';
import '../network/endpoints.dart';
import '../services/cache_service.dart';
import '../errors/failures.dart';
import '../utils/date_formatter.dart';
import 'base_repository.dart';

/// Repositório para operações de transações.
class TransactionRepository extends BaseRepository {
  TransactionRepository({super.client});

  Future<List<TransactionModel>> fetchTransactions({
    String? type,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) queryParams['type'] = type;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      
      final response = await client.client.get<dynamic>(
        ApiEndpoints.transactions,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      final items = extractListFromResponse(response.data);
      
      return items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw const ParseFailure('Formato de transação inválido');
            }
            return TransactionModel.fromMap(e);
          })
          .toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw handleError(e);
    }
  }

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
  }) async {
    final payload = {
      'type': type,
      'description': description,
      'amount': amount,
      'date': DateFormatter.toApiFormat(date),
      if (categoryId != null) 'category_id': categoryId,
      if (isRecurring) 'is_recurring': true,
      if (isRecurring && recurrenceValue != null)
        'recurrence_value': recurrenceValue,
      if (isRecurring && recurrenceUnit != null)
        'recurrence_unit': recurrenceUnit,
      if (isRecurring && recurrenceEndDate != null)
        'recurrence_end_date': DateFormatter.toApiFormat(recurrenceEndDate),
    };
    final response = await client.client.post<Map<String, dynamic>>(
      ApiEndpoints.transactions,
      data: payload,
    );
    await CacheService.invalidateDashboard();
    await CacheService.invalidateMissions();
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await client.client.delete('${ApiEndpoints.transactions}$id/');
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
    } catch (e) {
      throw handleError(e);
    }
  }

  Future<Map<String, dynamic>> fetchTransactionDetails(String id) async {
    final response = await client.client
        .get<Map<String, dynamic>>('${ApiEndpoints.transactions}$id/details/');
    return response.data ?? <String, dynamic>{};
  }

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
  }) async {
    final payload = <String, dynamic>{};
    if (type != null) payload['type'] = type;
    if (description != null) payload['description'] = description;
    if (amount != null) payload['amount'] = amount;
    if (date != null) {
      payload['date'] = DateFormatter.toApiFormat(date);
    }
    if (categoryId != null) {
      payload['category_id'] = categoryId;
    }
    if (isRecurring != null) payload['is_recurring'] = isRecurring;
    if (recurrenceValue != null) payload['recurrence_value'] = recurrenceValue;
    if (recurrenceUnit != null) payload['recurrence_unit'] = recurrenceUnit;
    if (recurrenceEndDate != null) {
      payload['recurrence_end_date'] = DateFormatter.toApiFormat(recurrenceEndDate);
    }

    final response = await client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.transactions}$id/',
      data: payload,
    );
    
    // Invalidar cache após atualizar transação
    await CacheService.invalidateDashboard();
    await CacheService.invalidateMissions();
    
    return TransactionModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<List<TransactionModel>> fetchAvailableIncomes({double? minAmount}) async {
    final queryParams = <String, dynamic>{};
    if (minAmount != null) {
      queryParams['min_amount'] = minAmount.toString();
    }
    
    final response = await client.client.get<dynamic>(
      '${ApiEndpoints.transactionLinks}available_sources/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = extractListFromResponse(response.data);
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransactionModel>> fetchPendingExpenses({double? maxAmount}) async {
    final queryParams = <String, dynamic>{};
    if (maxAmount != null) {
      queryParams['max_amount'] = maxAmount.toString();
    }
    
    final response = await client.client.get<dynamic>(
      '${ApiEndpoints.transactionLinks}available_targets/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = extractListFromResponse(response.data);
    return items
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionLinkModel> createTransactionLink(
      CreateTransactionLinkRequest request) async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}quick_link/',
      data: request.toMap(),
    );
    
    return TransactionLinkModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteTransactionLink(String linkId) async {
    await client.client.delete('${ApiEndpoints.transactionLinks}$linkId/');
  }

  Future<Map<String, dynamic>> fetchPendingSummary({
    String sortBy = 'urgency',
  }) async {
    final response = await client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}pending_summary/',
      queryParameters: {'sort_by': sortBy},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createBulkPayment({
    required List<Map<String, dynamic>> payments,
    String? description,
  }) async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}bulk_payment/',
      data: {
        'payments': payments,
        if (description != null) 'description': description,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<TransactionLinkModel>> fetchTransactionLinks({
    String? linkType,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, dynamic>{};
    if (linkType != null) queryParams['link_type'] = linkType;
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    
    final response = await client.client.get<dynamic>(
      ApiEndpoints.transactionLinks,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    final items = extractListFromResponse(response.data);
    
    return items
        .map((e) {
          if (e is! Map<String, dynamic>) {
            throw const ParseFailure('Formato de link inválido');
          }
          return TransactionLinkModel.fromMap(e);
        })
        .toList();
  }

  Future<Map<String, dynamic>> fetchPaymentReport({
    String? startDate,
    String? endDate,
    int? categoryId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (categoryId != null) queryParams['category'] = categoryId.toString();
    
    final response = await client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}payment_report/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    return response.data ?? <String, dynamic>{};
  }
}
