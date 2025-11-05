/// Endpoints centrais da API REST.
class ApiEndpoints {
  const ApiEndpoints._();

  static const String register = '/api/auth/register/';
  static const String token = '/api/token/';
  static const String tokenRefresh = '/api/token/refresh/';
  static const String dashboard = '/api/dashboard/';
  static const String categories = '/api/categories/';
  static const String transactions = '/api/transactions/';
  static const String transactionLinks = '/api/transaction-links/';
  static const String missions = '/api/missions/';
  static const String missionProgress = '/api/mission-progress/';
  static const String goals = '/api/goals/';
  static const String profile = '/api/profile/';
  static const String user = '/api/user/';
  static const String friendships = '/api/friendships/';
  static const String leaderboard = '/api/leaderboard/';
}
