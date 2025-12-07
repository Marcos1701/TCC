class ApiEndpoints {
  const ApiEndpoints._();

  static const String register = '/api/auth/register/';
  static const String token = '/api/token/';
  static const String tokenRefresh = '/api/token/refresh/';
  static const String dashboard = '/api/dashboard/';
  static const String dashboardAnalytics = '/api/dashboard/analytics/';
  static const String categories = '/api/categories/';
  static const String transactions = '/api/transactions/';
  static const String transactionLinks = '/api/transaction-links/';
  static const String missions = '/api/missions/';
  static const String missionsRecommend = '/api/missions/recommend/';
  static const String missionsByCategory = '/api/missions/by-category/';
  static const String missionsContextAnalysis = '/api/missions/context-analysis/';
  static const String missionsTemplates = '/api/missions/templates/';
  static const String missionsGenerateFromTemplate = '/api/missions/generate-from-template/';
  static const String missionProgress = '/api/mission-progress/';
  static const String profile = '/api/profile/';
  static const String user = '/api/user/';
  static const String simplifiedOnboarding = '/api/onboarding/simplified/';
  
  static const String adminDashboard = '/api/admin-panel/';
  static const String adminMissions = '/api/admin-panel/missoes/';
  static const String adminMissionsGenerate = '/api/admin-panel/missoes/gerar/';
  static const String adminMissionTypes = '/api/admin-panel/missoes/tipos/';
  static const String adminMissionValidate = '/api/admin-panel/missoes/validar/';
  static const String adminMissionSelectOptions = '/api/admin-panel/missoes/opcoes-selecao/';
  static const String adminCategories = '/api/admin-panel/categorias/';
  static const String adminUsers = '/api/admin-panel/usuarios/';
}
