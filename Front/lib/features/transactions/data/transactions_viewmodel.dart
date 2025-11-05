import 'package:flutter/foundation.dart';

import '../../../core/models/transaction.dart';
import '../../../core/models/transaction_link.dart';
import '../../../core/repositories/finance_repository.dart';
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
  TransactionsViewModel({FinanceRepository? repository})
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;
  
  // Estado
  TransactionsViewState _state = TransactionsViewState.initial;
  List<TransactionModel> _transactions = [];
  List<TransactionLinkModel> _links = [];
  String? _filter;
  String? _errorMessage;
  
  // Transações pendentes (otimistas)
  final Map<String, TransactionModel> _pendingTransactions = {};
  
  // Getters
  TransactionsViewState get state => _state;
  List<TransactionModel> get transactions {
    // Combina transações reais com pendentes
    final pending = _pendingTransactions.values.toList();
    return [...pending, ..._transactions];
  }
  List<TransactionLinkModel> get links => _links;
  String? get filter => _filter;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == TransactionsViewState.loading;
  bool get hasError => _state == TransactionsViewState.error;
  bool get isEmpty => transactions.isEmpty && !isLoading;
  
  /// Carrega transações do repositório
  Future<void> loadTransactions({String? type}) async {
    _filter = type;
    _state = TransactionsViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _repository.fetchTransactions(type: type);
      _links = await _repository.fetchTransactionLinks();
      _state = TransactionsViewState.success;
      _errorMessage = null;
    } catch (e) {
      _state = TransactionsViewState.error;
      _errorMessage = 'Erro ao carregar transações: ${e.toString()}';
      debugPrint('Erro ao carregar transações: $e');
    } finally {
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
      debugPrint('Erro ao atualizar transações silenciosamente: $e');
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
    // 1. Cria transação temporária (otimista)
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempTransaction = TransactionModel(
      id: -1, // ID temporário
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
      // 3. Envia ao servidor em background
      final created = await _repository.createTransaction(
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

      // 4. Remove transação temporária
      _pendingTransactions.remove(tempId);

      // 5. Adiciona transação real à lista
      _transactions.insert(0, created);
      
      // 6. Invalida cache para outras telas
      CacheManager().invalidateAfterTransaction(action: 'transaction created');
      
      notifyListeners();
      return created;
    } catch (e) {
      // 7. Rollback em caso de erro
      _pendingTransactions.remove(tempId);
      notifyListeners();
      debugPrint('Erro ao criar transação: $e');
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
      // 2. Deleta no servidor
      await _repository.deleteTransaction(transaction.id);
      
      // 3. Invalida cache
      CacheManager().invalidateAfterTransaction(action: 'transaction deleted');
      
      return true;
    } catch (e) {
      // 4. Rollback em caso de erro
      _transactions.insert(index, removed);
      notifyListeners();
      debugPrint('Erro ao deletar transação: $e');
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
      debugPrint('Erro ao aplicar filtro: $e');
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
