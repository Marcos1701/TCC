import 'package:flutter/foundation.dart';

import '../../../core/models/transaction.dart';
import '../../../core/models/transaction_link.dart';
import '../../../core/repositories/transaction_repository.dart';
import '../../../core/repositories/interfaces/i_transaction_repository.dart';
import '../../../core/services/cache_manager.dart';

enum TransactionsViewState {
  initial,
  loading,
  success,
  error,
}

class TransactionsViewModel extends ChangeNotifier {
  TransactionsViewModel({ITransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  final ITransactionRepository _repository;
  
  ITransactionRepository get repository => _repository;
  
  bool _isDisposed = false;
  
  TransactionsViewState _state = TransactionsViewState.initial;
  List<TransactionModel> _transactions = [];
  List<TransactionLinkModel> _links = [];
  String? _filter;
  String? _scheduleFilter; // null = all, 'scheduled' = future only, 'effective' = past/present only
  String _searchQuery = '';
  String? _errorMessage;
  
  bool _hasMore = true;
  final int _pageSize = 50;
  bool _isLoadingMore = false;
  
  final Map<String, TransactionModel> _pendingTransactions = {};
  
  static int _tempIdCounter = 0;
  
  TransactionsViewState get state => _state;
  List<TransactionModel> get transactions {
    final pending = _pendingTransactions.values.toList();
    var result = [...pending, ..._transactions];
    
    // Apply schedule filter
    if (_scheduleFilter == 'scheduled') {
      result = result.where((t) => t.isScheduled).toList();
    } else if (_scheduleFilter == 'effective') {
      result = result.where((t) => !t.isScheduled).toList();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) => 
        t.description.toLowerCase().contains(query) ||
        (t.category?.name.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    return result;
  }
  List<TransactionLinkModel> get links => _links;
  String? get filter => _filter;
  String? get scheduleFilter => _scheduleFilter;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == TransactionsViewState.loading;
  bool get hasError => _state == TransactionsViewState.error;
  bool get isEmpty => transactions.isEmpty && !isLoading;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
  
  Future<void> loadTransactions({String? type}) async {
    if (_isDisposed) return;
    
    _filter = type;
    _state = TransactionsViewState.loading;
    _errorMessage = null;
    _hasMore = true;
    _safeNotifyListeners();

    try {
      if (kDebugMode) {
        debugPrint('📥 TransactionsViewModel: Iniciando carregamento de transações...');
      }
      
      _transactions = await _repository.fetchTransactions(
        type: type,
        limit: _pageSize,
        offset: 0,
      );
      
      if (kDebugMode) {
        debugPrint('✅ TransactionsViewModel: ${_transactions.length} transações carregadas');
      }
      
      try {
        _links = await _repository.fetchTransactionLinks();
        
        if (kDebugMode) {
          debugPrint('✅ TransactionsViewModel: ${_links.length} links carregados');
        }
      } catch (linkError) {
        if (kDebugMode) {
          debugPrint('⚠️ TransactionsViewModel: Erro ao carregar links (ignorado): $linkError');
        }
        _links = [];
      }
      
      _hasMore = _transactions.length >= _pageSize;
      _state = TransactionsViewState.success;
      _errorMessage = null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ TransactionsViewModel: Erro ao carregar transações: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      _state = TransactionsViewState.error;
      _errorMessage = 'Erro ao carregar transações: ${e.toString()}';
    } finally {
      _safeNotifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    _safeNotifyListeners();

    try {
      final currentOffset = _transactions.length;
      final moreTransactions = await _repository.fetchTransactions(
        type: _filter,
        limit: _pageSize,
        offset: currentOffset,
      );
      
      if (moreTransactions.isEmpty || moreTransactions.length < _pageSize) {
        _hasMore = false;
      }
      
      _transactions.addAll(moreTransactions);
    } catch (e) {
      debugPrint('Error loading more transactions: $e');
    } finally {
      _isLoadingMore = false;
      _safeNotifyListeners();
    }
  }

  Future<void> refreshSilently() async {
    if (_isDisposed) return;
    
    try {
      _transactions = await _repository.fetchTransactions(type: _filter);
      
      try {
        _links = await _repository.fetchTransactionLinks();
      } catch (linkError) {
        if (kDebugMode) {
          debugPrint('⚠️ Erro ao atualizar links silenciosamente (ignorado): $linkError');
        }
      }
      
      _safeNotifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao atualizar transações silenciosamente: $e');
      }
    }
  }

  Future<TransactionModel?> createTransaction({
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
    if (description.trim().isEmpty) {
      _errorMessage = 'Descrição não pode ser vazia';
      _state = TransactionsViewState.error;
      _safeNotifyListeners();
      return null;
    }

    if (amount <= 0) {
      _errorMessage = 'Valor deve ser maior que zero';
      _state = TransactionsViewState.error;
      _safeNotifyListeners();
      return null;
    }

    final now = DateTime.now();
    final maxFutureDate = now.add(const Duration(days: 365 * 10));
    if (date.isAfter(maxFutureDate)) {
      _errorMessage = 'Data não pode ser mais de 10 anos no futuro';
      _state = TransactionsViewState.error;
      _safeNotifyListeners();
      return null;
    }

    if (isRecurring) {
      if (recurrenceValue == null || recurrenceValue <= 0) {
        _errorMessage = 'Valor de recorrência deve ser maior que zero';
        _state = TransactionsViewState.error;
        _safeNotifyListeners();
        return null;
      }

      if (recurrenceUnit == null || recurrenceUnit.isEmpty) {
        _errorMessage = 'Unidade de recorrência não pode ser vazia';
        _state = TransactionsViewState.error;
        _safeNotifyListeners();
        return null;
      }
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${++_tempIdCounter}';
    final tempTransaction = TransactionModel(
      id: tempId,
      type: type,
      description: description,
      amount: amount,
      date: date,
      category: null,
      isRecurring: isRecurring,
      recurrenceValue: recurrenceValue,
      recurrenceUnit: recurrenceUnit,
      recurrenceEndDate: recurrenceEndDate,
    );

    _pendingTransactions[tempId] = tempTransaction;
    _safeNotifyListeners();

    try {
      final response = await _repository.createTransaction(
        type: type,
        description: description,
        amount: amount,
        date: date,
        categoryId: categoryId,
        isRecurring: isRecurring,
        recurrenceValue: recurrenceValue,
        recurrenceUnit: recurrenceUnit,
        recurrenceEndDate: recurrenceEndDate,
      );

      _pendingTransactions.remove(tempId);

      final created = TransactionModel.fromMap(response);
      _transactions.insert(0, created);
      
      CacheManager().invalidateAfterTransaction(action: 'transaction created');
      
      _safeNotifyListeners();
      return created;
    } catch (e) {
      _pendingTransactions.remove(tempId);
      _safeNotifyListeners();
      if (kDebugMode) {
        debugPrint('Erro ao criar transação: $e');
      }
      rethrow;
    }
  }


  Future<bool> deleteTransaction(TransactionModel transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index == -1) return false;

    final removed = _transactions.removeAt(index);
    _safeNotifyListeners();

    try {
      await _repository.deleteTransaction(transaction.identifier);
      
      CacheManager().invalidateAfterTransaction(action: 'transaction deleted');
      
      return true;
    } catch (e) {
      _transactions.insert(index, removed);
      _safeNotifyListeners();
      if (kDebugMode) {
        debugPrint('Erro ao deletar transação: $e');
      }
      rethrow;
    }
  }

  Future<void> updateFilter(String? newFilter) async {
    if (_filter == newFilter) return;
    _filter = newFilter;
    _state = TransactionsViewState.loading;
    _safeNotifyListeners();
    
    try {
      _transactions = await _repository.fetchTransactions(type: newFilter);
      
      try {
        _links = await _repository.fetchTransactionLinks();
      } catch (linkError) {
        if (kDebugMode) {
          debugPrint('⚠️ Erro ao carregar links no filtro (ignorado): $linkError');
        }
        _links = [];
      }
      
      _state = TransactionsViewState.success;
    } catch (e) {
      _state = TransactionsViewState.error;
      _errorMessage = 'Erro ao aplicar filtro: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Erro ao aplicar filtro: $e');
      }
    } finally {
      _safeNotifyListeners();
    }
  }

  /// Update schedule filter (null = all, 'scheduled' = future, 'effective' = past/present)
  void updateScheduleFilter(String? newScheduleFilter) {
    if (_scheduleFilter == newScheduleFilter) return;
    _scheduleFilter = newScheduleFilter;
    _safeNotifyListeners();
  }

  /// Update search query for filtering by description
  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _safeNotifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == TransactionsViewState.error) {
      _state = TransactionsViewState.initial;
    }
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pendingTransactions.clear();
    super.dispose();
  }
}
