/// Endpoints centrais da API REST.
class ApiEndpoints {
  const ApiEndpoints._();

  static const String register = '/api/auth/register/';
  static const String token = '/api/token/';
  static const String tokenRefresh = '/api/token/refresh/';
  static const String dashboard = '/api/dashboard/';
  static const String categories = '/api/categories/';
  static const String transactions = '/api/transactions/';
  static const String missions = '/api/missions/';
  static const String missionProgress = '/api/mission-progress/';
  static const String goals = '/api/goals/';
  static const String profile = '/api/profile/';
}
