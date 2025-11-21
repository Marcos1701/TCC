import 'package:flutter/foundation.dart';

import '../../../core/models/leaderboard.dart';
import '../../../core/repositories/finance_repository.dart';
import '../../../core/services/analytics_service.dart';

/// ViewModel para gerenciar o estado do ranking.
class LeaderboardViewModel extends ChangeNotifier {
  LeaderboardViewModel({FinanceRepository? repository})
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

  // Estado do ranking geral
  LeaderboardResponse? _generalLeaderboard;
  bool _isLoadingGeneral = false;
  String? _generalError;

  // Estado do ranking de amigos
  LeaderboardResponse? _friendsLeaderboard;
  bool _isLoadingFriends = false;
  String? _friendsError;

  // Getters
  LeaderboardResponse? get generalLeaderboard => _generalLeaderboard;
  bool get isLoadingGeneral => _isLoadingGeneral;
  String? get generalError => _generalError;

  LeaderboardResponse? get friendsLeaderboard => _friendsLeaderboard;
  bool get isLoadingFriends => _isLoadingFriends;
  String? get friendsError => _friendsError;

  /// Carrega o ranking geral
  Future<void> loadGeneralLeaderboard({int page = 1, int pageSize = 50}) async {
    _isLoadingGeneral = true;
    _generalError = null;
    notifyListeners();

    try {
      _generalLeaderboard = await _repository.fetchLeaderboard(
        page: page,
        pageSize: pageSize,
      );
      _generalError = null;
    } catch (e) {
      _generalError = 'Erro ao carregar ranking: ${e.toString()}';
    } finally {
      _isLoadingGeneral = false;
      notifyListeners();
    }
  }

  /// Carrega o ranking de amigos
  Future<void> loadFriendsLeaderboard() async {
    _isLoadingFriends = true;
    _friendsError = null;
    notifyListeners();

    try {
      _friendsLeaderboard = await _repository.fetchFriendsLeaderboard();
      _friendsError = null;
      
      // Rastreia visualização do ranking
      AnalyticsService.trackLeaderboardViewed(
        friendsCount: _friendsLeaderboard?.leaderboard.length ?? 0,
      );
    } catch (e) {
      _friendsError = 'Erro ao carregar ranking de amigos: ${e.toString()}';
    } finally {
      _isLoadingFriends = false;
      notifyListeners();
    }
  }

  /// Recarrega ambos os rankings
  Future<void> refresh() async {
    // Recarregar apenas o ranking de amigos (o geral não é mais usado)
    await loadFriendsLeaderboard();
  }

  /// Limpa os dados
  void clear() {
    _generalLeaderboard = null;
    _friendsLeaderboard = null;
    _generalError = null;
    _friendsError = null;
    _isLoadingGeneral = false;
    _isLoadingFriends = false;
    notifyListeners();
  }
}
