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
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class TransactionRepository extends BaseRepository implements ITransactionRepository {
  TransactionRepository({super.client, AppDatabase? db}) 
      : _db = db ?? AppDatabase();

  final AppDatabase _db;
  
  static bool get _dbAvailable => !kIsWeb;
  
  // Request deduplication - STATIC to work across all repository instances
  static Future<List<TransactionModel>>? _transactionsFetchInFlight;
  static Future<List<TransactionLinkModel>>? _linksFetchInFlight;
  static String? _lastTransactionsFetchKey;

  @override
  Future<List<TransactionModel>> fetchTransactions({
    String? type,
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Create a key for this request to detect duplicates
    final requestKey = 'fetch_${type}_${limit}_${offset}_${startDate}_${endDate}';
    
    // If an identical request is already in-flight, return the same future
    if (_transactionsFetchInFlight != null && _lastTransactionsFetchKey == requestKey) {
      if (kDebugMode) {
        debugPrint('📡 TransactionRepository: Request already in-flight, reusing...');
      }
      return _transactionsFetchInFlight!;
    }
    
    // Store the request key and execute
    _lastTransactionsFetchKey = requestKey;
    _transactionsFetchInFlight = _doFetchTransactions(
      type: type, 
      limit: limit, 
      offset: offset,
      startDate: startDate,
      endDate: endDate,
    );
    
    try {
      final result = await _transactionsFetchInFlight!;
      return result;
    } finally {
      // Clear when done
      _transactionsFetchInFlight = null;
      _lastTransactionsFetchKey = null;
    }
  }

  Future<List<TransactionModel>> _doFetchTransactions({
    String? type,
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) queryParams['type'] = type;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      if (startDate != null) queryParams['start_date'] = DateFormatter.toApiFormat(startDate);
      if (endDate != null) queryParams['end_date'] = DateFormatter.toApiFormat(endDate);
      
      if (kDebugMode) {
        debugPrint('📡 TransactionRepository: Fetching transactions from API...');
      }
      
      final response = await client.client.get<dynamic>(
        ApiEndpoints.transactions,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      if (kDebugMode) {
        debugPrint('📡 TransactionRepository: Response received, parsing...');
      }
      
      final items = extractListFromResponse(response.data);
      final transactions = items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw const ParseFailure('Formato de transação inválido');
            }
            return TransactionModel.fromMap(e);
          })
          .toList();

      if (kDebugMode) {
        debugPrint('✅ TransactionRepository: ${transactions.length} transactions parsed');
      }

      if (_dbAvailable) {
        _saveTransactionsToDb(transactions).catchError((e) {
          if (kDebugMode) {
            debugPrint('⚠️ TransactionRepository: Error saving to DB: $e');
          }
        });
      }
      
      return transactions;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ TransactionRepository: Error fetching transactions: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        if (kDebugMode) {
          debugPrint('📦 TransactionRepository: Falling back to local DB...');
        }
        try {
          final dbTransactions = await _db.transactionsDao.getAllTransactions();
          return dbTransactions.map((t) => _mapToModel(t)).toList();
        } catch (dbError) {
          if (kDebugMode) {
            debugPrint('❌ TransactionRepository: DB fallback also failed: $dbError');
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> _saveTransactionsToDb(List<TransactionModel> transactions) async {
    if (!_dbAvailable) return;
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
      
      if (_dbAvailable) {
        _db.transactionsDao.insertTransaction(_mapToCompanion(transaction)).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ DB insert error (ignored): $e');
          return 0;
        });
      }
      
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
      return data;
    } catch (e) {
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
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
      
      if (_dbAvailable) {
        _db.transactionsDao.deleteTransaction(id).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ DB delete error (ignored): $e');
          return 0;
        });
      }
      
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
    } catch (e) {
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
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
      if (_dbAvailable && e is DioException && 
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
      
      if (_dbAvailable) {
        _db.transactionsDao.updateTransaction(_mapToCompanion(transaction)).catchError((e) {
          if (kDebugMode) debugPrint('⚠️ DB update error (ignored): $e');
          return false;
        });
      }
      
      await CacheService.invalidateDashboard();
      await CacheService.invalidateMissions();
      
      return transaction;
    } catch (e) {
      if (_dbAvailable && e is DioException && 
          (e.type == DioExceptionType.connectionTimeout || 
           e.type == DioExceptionType.connectionError)) {
        final current = await _db.transactionsDao.getTransactionById(id);
        if (current != null) {
          final updated = current.copyWith(
            type: type ?? current.type,
            description: description ?? current.description,
            amount: amount ?? current.amount,
            date: date ?? current.date,
            categoryId: Value(categoryId != null ? categoryId.toString() : current.categoryId),
            isRecurring: isRecurring ?? current.isRecurring,
            recurrenceValue: Value(recurrenceValue ?? current.recurrenceValue),
            recurrenceUnit: Value(recurrenceUnit ?? current.recurrenceUnit),
            recurrenceEndDate: Value(recurrenceEndDate ?? current.recurrenceEndDate),
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
        'source_transaction_id': sourceId,
        'target_transaction_id': targetId,
        'linked_amount': amount,
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
    // If an identical request is already in-flight, return the same future
    if (_linksFetchInFlight != null) {
      if (kDebugMode) {
        debugPrint('📡 TransactionRepository: Links request already in-flight, reusing...');
      }
      return _linksFetchInFlight!;
    }
    
    _linksFetchInFlight = _doFetchTransactionLinks(
      linkType: linkType,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    
    try {
      final result = await _linksFetchInFlight!;
      return result;
    } finally {
      _linksFetchInFlight = null;
    }
  }

  Future<List<TransactionLinkModel>> _doFetchTransactionLinks({
    String? linkType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (linkType != null) queryParams['link_type'] = linkType;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;
      
      if (kDebugMode) {
        debugPrint('📡 TransactionRepository: Fetching transaction links...');
      }
      
      final response = await client.client.get<dynamic>(
        ApiEndpoints.transactionLinks,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      if (kDebugMode) {
        debugPrint('📡 TransactionRepository: Links response received, parsing...');
      }
      
      final items = extractListFromResponse(response.data);
      
      final links = items
          .map((e) {
            if (e is! Map<String, dynamic>) {
              throw const ParseFailure('Formato de link inválido');
            }
            return TransactionLinkModel.fromMap(e);
          })
          .toList();
      
      if (kDebugMode) {
        debugPrint('✅ TransactionRepository: ${links.length} links parsed');
      }
      
      return links;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ TransactionRepository: Error fetching links: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
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