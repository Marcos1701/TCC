import 'package:flutter/foundation.dart';

import '../../../core/models/friendship.dart';
import '../../../core/models/user_search.dart';
import '../../../core/repositories/finance_repository.dart';

/// ViewModel para gerenciar amizades e solicitações.
class FriendsViewModel extends ChangeNotifier {
  FriendsViewModel({FinanceRepository? repository})
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

  // Estado de amigos
  List<FriendshipModel> _friends = [];
  bool _isLoadingFriends = false;
  String? _friendsError;

  // Estado de solicitações
  List<FriendshipModel> _requests = [];
  bool _isLoadingRequests = false;
  String? _requestsError;

  // Estado de busca
  List<UserSearchModel> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  String _searchQuery = '';

  // Getters
  List<FriendshipModel> get friends => _friends;
  bool get isLoadingFriends => _isLoadingFriends;
  String? get friendsError => _friendsError;

  List<FriendshipModel> get requests => _requests;
  bool get isLoadingRequests => _isLoadingRequests;
  String? get requestsError => _requestsError;

  List<UserSearchModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  String get searchQuery => _searchQuery;

  /// Carrega lista de amigos
  Future<void> loadFriends() async {
    _isLoadingFriends = true;
    _friendsError = null;
    notifyListeners();

    try {
      _friends = await _repository.fetchFriends();
      _friendsError = null;
    } catch (e) {
      _friendsError = 'Erro ao carregar amigos: ${e.toString()}';
      debugPrint('Erro ao carregar amigos: $e');
    } finally {
      _isLoadingFriends = false;
      notifyListeners();
    }
  }

  /// Carrega solicitações pendentes
  Future<void> loadRequests() async {
    _isLoadingRequests = true;
    _requestsError = null;
    notifyListeners();

    try {
      _requests = await _repository.fetchFriendRequests();
      _requestsError = null;
    } catch (e) {
      _requestsError = 'Erro ao carregar solicitações: ${e.toString()}';
      debugPrint('Erro ao carregar solicitações: $e');
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  /// Busca usuários
  Future<void> searchUsers(String query) async {
    _searchQuery = query;

    if (query.trim().length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      _searchResults = await _repository.searchUsers(query: query);
      _searchError = null;
    } catch (e) {
      _searchError = 'Erro ao buscar usuários: ${e.toString()}';
      debugPrint('Erro ao buscar usuários: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Envia solicitação de amizade
  Future<bool> sendFriendRequest(int friendId) async {
    try {
      await _repository.sendFriendRequest(friendId: friendId);
      
      // Atualizar resultado de busca
      _searchResults = _searchResults.map((user) {
        if (user.id == friendId) {
          return user.copyWith(hasPendingRequest: true);
        }
        return user;
      }).toList();
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erro ao enviar solicitação: $e');
      return false;
    }
  }

  /// Aceita solicitação de amizade
  Future<bool> acceptFriendRequest(int requestId) async {
    try {
      await _repository.acceptFriendRequest(requestId: requestId);
      
      // Remover das solicitações e recarregar amigos
      await Future.wait([
        loadRequests(),
        loadFriends(),
      ]);
      
      return true;
    } catch (e) {
      debugPrint('Erro ao aceitar solicitação: $e');
      return false;
    }
  }

  /// Rejeita solicitação de amizade
  Future<bool> rejectFriendRequest(int requestId) async {
    try {
      await _repository.rejectFriendRequest(requestId: requestId);
      
      // Remover das solicitações
      _requests = _requests.where((r) => r.id != requestId).toList();
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Erro ao rejeitar solicitação: $e');
      return false;
    }
  }

  /// Remove amizade
  Future<bool> removeFriend(int friendshipId) async {
    try {
      await _repository.removeFriend(friendshipId: friendshipId);
      
      // Remover da lista de amigos
      _friends = _friends.where((f) => f.id != friendshipId).toList();
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Erro ao remover amigo: $e');
      return false;
    }
  }

  /// Recarrega tudo
  Future<void> refresh() async {
    await Future.wait([
      loadFriends(),
      loadRequests(),
    ]);
  }

  /// Limpa os dados de busca
  void clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    _searchError = null;
    notifyListeners();
  }

  /// Limpa todos os dados
  void clear() {
    _friends = [];
    _requests = [];
    _searchResults = [];
    _friendsError = null;
    _requestsError = null;
    _searchError = null;
    _isLoadingFriends = false;
    _isLoadingRequests = false;
    _isSearching = false;
    _searchQuery = '';
    notifyListeners();
  }
}
