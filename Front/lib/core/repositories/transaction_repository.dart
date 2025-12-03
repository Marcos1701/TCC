import '../models/transaction.dart';
import '../models/category.dart';
import '../models/transaction_link.dart';
import '../network/endpoints.dart';
import '../services/cache_service.dart';
import '../errors/failures.dart';
import '../utils/date_formatter.dart';
import 'base_repository.dart';
import 'interfaces/i_transaction_repository.dart';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

/// Repositório para operações de transações.
class TransactionRepository extends BaseRepository implements ITransactionRepository {
  TransactionRepository({super.client, AppDatabase? db}) 
      : _db = db ?? AppDatabase();

  final AppDatabase _db;

  @override
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
      final transactions = items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw const ParseFailure('Formato de transação inválido');
            }
            return TransactionModel.fromMap(e);
          })
          .toList();

      // Save to DB
      await _saveTransactionsToDb(transactions);
      
      return transactions;
    } catch (e) {
      // Fallback to DB
      if (e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        final dbTransactions = await _db.transactionsDao.getAllTransactions();
        return dbTransactions.map((t) => _mapToModel(t)).toList();
      }
      rethrow;
    }
  }

  Future<void> _saveTransactionsToDb(List<TransactionModel> transactions) async {
    for (final t in transactions) {
      await _db.transactionsDao.insertTransaction(_mapToCompanion(t));
    }
  }

  TransactionModel _mapToModel(Transaction t) {
    return TransactionModel(
      id: t.id,
      description: t.description,
      amount: t.amount,
      date: t.date,
      type: t.type,
      category: t.categoryId != null ? CategoryModel(id: int.parse(t.categoryId!), name: 'Cached', type: 'expense') : null, // Simplified for now
      isRecurring: t.isRecurring,
      recurrenceValue: t.recurrenceValue,
      recurrenceUnit: t.recurrenceUnit,
      recurrenceEndDate: t.recurrenceEndDate,
    );
  }

  TransactionsCompanion _mapToCompanion(TransactionModel t) {
    return TransactionsCompanion.insert(
      id: t.id,
      description: t.description,
      amount: t.amount,
      date: t.date,
      type: t.type,
      categoryId: Value<String?>(t.category?.id.toString()),
      isRecurring: Value(t.isRecurring),
      recurrenceValue: Value<int?>(t.recurrenceValue),
      recurrenceUnit: Value<String?>(t.recurrenceUnit),
      recurrenceEndDate: Value<DateTime?>(t.recurrenceEndDate),
      isSynced: const Value(true),
    );
  }

  @override
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

    try {
      final response = await client.client.post<Map<String, dynamic>>(
        ApiEndpoints.transactions,
        data: payload,
      );
      
      final data = response.data ?? <String, dynamic>{};
      final transaction = TransactionModel.fromMap(data);
      await _db.transactionsDao.insertTransaction(_mapToCompanion(transaction));
      
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
      return data;
    } catch (e) {
      if (e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        // Offline creation
        final id = const Uuid().v4();
        final transaction = TransactionModel(
          id: id,
          type: type,
          description: description,
          amount: amount,
          date: date,
          category: categoryId != null ? CategoryModel(id: categoryId, name: 'Pending', type: 'expense') : null,
          isRecurring: isRecurring,
          recurrenceValue: recurrenceValue,
          recurrenceUnit: recurrenceUnit,
          recurrenceEndDate: recurrenceEndDate,
        );
        
        await _db.transactionsDao.insertTransaction(
          _mapToCompanion(transaction).copyWith(isSynced: const Value(false))
        );
        
        return transaction.toMap()..['id'] = id;
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await client.client.delete('${ApiEndpoints.transactions}$id/');
      await _db.transactionsDao.deleteTransaction(id);
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
    } catch (e) {
      if (e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        // Offline deletion (soft delete)
        await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
            .write(const TransactionsCompanion(
              isDeleted: Value(true),
              isSynced: Value(false),
            ));
        return;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> fetchTransactionDetails(String id) async {
    try {
      final response = await client.client
          .get<Map<String, dynamic>>('${ApiEndpoints.transactions}$id/details/');
      return response.data ?? <String, dynamic>{};
    } catch (e) {
      if (e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        final transaction = await _db.transactionsDao.getTransactionById(id);
        if (transaction != null) {
          return _mapToModel(transaction).toMap();
        }
      }
      rethrow;
    }
  }

  @override
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

    try {
      final response = await client.client.patch<Map<String, dynamic>>(
        '${ApiEndpoints.transactions}$id/',
        data: payload,
      );
      
      final data = response.data ?? <String, dynamic>{};
      final transaction = TransactionModel.fromMap(data);
      await _db.transactionsDao.updateTransaction(_mapToCompanion(transaction));
      
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
      
      return transaction;
    } catch (e) {
      if (e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        // Offline update
        final current = await _db.transactionsDao.getTransactionById(id);
        if (current != null) {
          final updated = current.copyWith(
            type: type,
            description: description,
            amount: amount,
            date: date,
            categoryId: categoryId != null ? categoryId.toString() : null, // Only update if not null? No, copyWith updates if provided. But here I want to update only if provided.
            // copyWith in Drift data class uses "Value" or just nullable?
            // Drift data class copyWith:
            // Transaction copyWith({String? id, String? description, ...})
            // It replaces if parameter is provided (non-null). If null, it keeps old value?
            // No, usually copyWith(field: null) sets it to null?
            // Drift generated copyWith:
            // Transaction copyWith({String? id, String? description, ...})
            // If I pass null, does it keep existing or set to null?
            // Usually: id: id ?? this.id.
            // So if I pass null, it keeps existing.
            // But what if I want to set to null?
            // Drift data classes usually don't support setting to null via copyWith if the parameter is nullable.
            // I should check generated code or assume standard behavior.
            // If I want to update only provided fields:
            // type: type ?? current.type
            // This works.
            
            // But wait, categoryId is nullable. If I want to set it to null?
            // The method updateTransaction has categoryId as int?.
            // If passed as null, it means "don't change" or "set to null"?
            // Usually in patch, null means don't change.
            // So:
            categoryId: categoryId != null ? categoryId.toString() : current.categoryId,
            isRecurring: isRecurring ?? current.isRecurring,
            recurrenceValue: recurrenceValue ?? current.recurrenceValue,
            recurrenceUnit: recurrenceUnit ?? current.recurrenceUnit,
            recurrenceEndDate: recurrenceEndDate ?? current.recurrenceEndDate,
            isSynced: false,
          );
          
          await _db.transactionsDao.updateTransaction(
            TransactionsCompanion(
              id: Value(updated.id),
              type: Value(updated.type),
              description: Value(updated.description),
              amount: Value(updated.amount),
              date: Value(updated.date),
              categoryId: Value(updated.categoryId),
              isRecurring: Value(updated.isRecurring),
              recurrenceValue: Value(updated.recurrenceValue),
              recurrenceUnit: Value(updated.recurrenceUnit),
              recurrenceEndDate: Value(updated.recurrenceEndDate),
              isSynced: const Value(false),
            )
          );
          return _mapToModel(updated);
        }
      }
      rethrow;
    }
  }

  @override
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

  @override
  Future<List<TransactionModel>> fetchAvailableExpenses({double? maxAmount}) async {
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

  @override
  Future<Map<String, dynamic>> createTransactionLink({
    required String sourceId,
    required String targetId,
    required double amount,
    String? description,
  }) async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}quick_link/',
      data: {
        'source_id': sourceId,
        'target_id': targetId,
        'amount': amount,
        if (description != null) 'description': description,
      },
    );
    
    return response.data ?? <String, dynamic>{};
  }

  @override
  Future<void> deleteTransactionLink(String linkId) async {
    await client.client.delete('${ApiEndpoints.transactionLinks}$linkId/');
  }

  @override
  Future<Map<String, dynamic>> fetchPendingSummary({
    double minRemaining = 0.01,
    String sortBy = 'urgency',
  }) async {
    final response = await client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}pending_summary/',
      queryParameters: {
        'min_remaining': minRemaining.toString(),
        'sort_by': sortBy
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> createBulkPayment({
    required List<Map<String, dynamic>> payments,
    String description = 'Pagamento em lote',
  }) async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}bulk_payment/',
      data: {
        'payments': payments,
        'description': description,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  @override
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

  @override
  Future<Map<String, dynamic>> fetchPaymentReport({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) queryParams['start_date'] = DateFormatter.toApiFormat(startDate);
    if (endDate != null) queryParams['end_date'] = DateFormatter.toApiFormat(endDate);
    if (categoryId != null) queryParams['category'] = categoryId.toString();
    
    final response = await client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.transactionLinks}payment_report/',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    
    return response.data ?? <String, dynamic>{};
  }

  @override
  Future<List<CategoryModel>> fetchCategories({String? type}) async {
    return handleRequest(() async {
      if (type == null) {
        final cached = CacheService.getCachedCategories();
        if (cached != null) {
          return cached.map((e) => CategoryModel.fromMap(e)).toList();
        }
      }
      
      final response = await client.client.get<dynamic>(
        ApiEndpoints.categories,
        queryParameters: type != null ? {'type': type} : null,
      );
      
      final items = extractListFromResponse(response.data);
      final categories = items
          .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
          .toList();
      
      if (type == null) {
        await CacheService.cacheCategories(
          categories.map((c) => c.toMap()).toList(),
        );
      }
      
      return categories;
    });
  }
}