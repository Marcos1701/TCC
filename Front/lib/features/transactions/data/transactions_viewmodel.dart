import 'package:flutter/foundation.dart';

import '../../../core/models/transaction.dart';
import '../../../core/models/transaction_link.dart';
import '../../../core/repositories/finance_repository.dart'; // Keep for backward compatibility if needed, or remove if unused
import '../../../core/repositories/transaction_repository.dart';
import '../../../core/repositories/interfaces/i_transaction_repository.dart';
import '../../../core/services/cache_manager.dart';

/// Estados do ViewModel
enum TransactionsViewState {
  initial,
  loading,
  success,
  error,
}

/// ViewModel para gerenciar transações com atualização otimista
class TransactionsViewModel extends ChangeNotifier {
  TransactionsViewModel({ITransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  final ITransactionRepository _repository;
  
  // Estado
  TransactionsViewState _state = TransactionsViewState.initial;
  List<TransactionModel> _transactions = [];
  List<TransactionLinkModel> _links = [];
  String? _filter;
  String? _errorMessage;
  
  bool _hasMore = true;
  final int _pageSize = 50;
  bool _isLoadingMore = false;
  
  // Transações pendentes (otimistas)
  final Map<String, TransactionModel> _pendingTransactions = {};
  
  // Contador para IDs únicos (evita race condition)
  static int _tempIdCounter = 0;
  
  // Getters
  TransactionsViewState get state => _state;
  List<TransactionModel> get transactions {
    final pending = _pendingTransactions.values.toList();
    return [...pending, ..._transactions];
  }
  List<TransactionLinkModel> get links => _links;
  String? get filter => _filter;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == TransactionsViewState.loading;
  bool get hasError => _state == TransactionsViewState.error;
  bool get isEmpty => transactions.isEmpty && !isLoading;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  
  /// Carrega transações do repositório
  Future<void> loadTransactions({String? type}) async {
    _filter = type;
    _state = TransactionsViewState.loading;
    _errorMessage = null;
    _hasMore = true;
    notifyListeners();

    try {
      _transactions = await _repository.fetchTransactions(
        type: type,
        limit: _pageSize,
        offset: 0,
      );
      _links = await _repository.fetchTransactionLinks();
      _hasMore = _transactions.length >= _pageSize;
      _state = TransactionsViewState.success;
      _errorMessage = null;
    } catch (e) {
      _state = TransactionsViewState.error;
      _errorMessage = 'Erro ao carregar transações: ${e.toString()}';
    } finally {
      notifyListeners();
    }
  }

  /// Carrega mais transações (paginação)
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

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
      // Mantém estado atual em caso de erro de paginação
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Atualiza transações sem mudar o estado de loading
  Future<void> refreshSilently() async {
    try {
      _transactions = await _repository.fetchTransactions(type: _filter);
      _links = await _repository.fetchTransactionLinks();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao atualizar transações silenciosamente: $e');
      }
    }
  }

  /// Cria transação com atualização otimista
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
    // === VALIDAÇÕES LOCAIS ===
    // Validar descrição
    if (description.trim().isEmpty) {
      _errorMessage = 'Descrição não pode ser vazia';
      _state = TransactionsViewState.error;
      notifyListeners();
      return null;
    }

    // Validar valor
    if (amount <= 0) {
      _errorMessage = 'Valor deve ser maior que zero';
      _state = TransactionsViewState.error;
      notifyListeners();
      return null;
    }

    // Validar data
    final now = DateTime.now();
    final maxFutureDate = now.add(const Duration(days: 365 * 10)); // 10 anos
    if (date.isAfter(maxFutureDate)) {
      _errorMessage = 'Data não pode ser mais de 10 anos no futuro';
      _state = TransactionsViewState.error;
      notifyListeners();
      return null;
    }

    // Validar recorrência
    if (isRecurring) {
      if (recurrenceValue == null || recurrenceValue <= 0) {
        _errorMessage = 'Valor de recorrência deve ser maior que zero';
        _state = TransactionsViewState.error;
        notifyListeners();
        return null;
      }

      if (recurrenceUnit == null || recurrenceUnit.isEmpty) {
        _errorMessage = 'Unidade de recorrência não pode ser vazia';
        _state = TransactionsViewState.error;
        notifyListeners();
        return null;
      }
    }

    // 1. Cria transação temporária (otimista) com ID único
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${++_tempIdCounter}';
    final tempTransaction = TransactionModel(
      id: tempId, // ID temporário como String
      type: type,
      description: description,
      amount: amount,
      date: date,
      category: null, // Será atualizado quando o servidor responder
      isRecurring: isRecurring,
      recurrenceValue: recurrenceValue,
      recurrenceUnit: recurrenceUnit,
      recurrenceEndDate: recurrenceEndDate,
    );

    // 2. Adiciona à lista local imediatamente
    _pendingTransactions[tempId] = tempTransaction;
    notifyListeners();

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
      
      notifyListeners();
      return created;
    } catch (e) {
      // 7. Rollback em caso de erro
      _pendingTransactions.remove(tempId);
      notifyListeners();
      if (kDebugMode) {
        debugPrint('Erro ao criar transação: $e');
      }
      rethrow;
    }
  }


  /// Deleta transação com atualização otimista
  Future<bool> deleteTransaction(TransactionModel transaction) async {
    // 1. Remove da lista local imediatamente (otimista)
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index == -1) return false;

    final removed = _transactions.removeAt(index);
    notifyListeners();

    try {
      // 2. Deleta no servidor usando UUID se disponível
      await _repository.deleteTransaction(transaction.identifier);
      
      // 3. Invalida cache
      CacheManager().invalidateAfterTransaction(action: 'transaction deleted');
      
      return true;
    } catch (e) {
      // 4. Rollback em caso de erro
      _transactions.insert(index, removed);
      notifyListeners();
      if (kDebugMode) {
        debugPrint('Erro ao deletar transação: $e');
      }
      rethrow;
    }
  }

  /// Atualiza filtro e recarrega
  Future<void> updateFilter(String? newFilter) async {
    if (_filter == newFilter) return;
    _filter = newFilter;
    _state = TransactionsViewState.loading;
    notifyListeners();
    
    try {
      _transactions = await _repository.fetchTransactions(type: newFilter);
      _links = await _repository.fetchTransactionLinks();
      _state = TransactionsViewState.success;
    } catch (e) {
      _state = TransactionsViewState.error;
      _errorMessage = 'Erro ao aplicar filtro: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Erro ao aplicar filtro: $e');
      }
    } finally {
      notifyListeners();
    }
  }

  /// Limpa erro
  void clearError() {
    _errorMessage = null;
    if (_state == TransactionsViewState.error) {
      _state = TransactionsViewState.initial;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingTransactions.clear();
    super.dispose();
  }
}
