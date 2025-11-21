import 'package:flutter/foundation.dart';

/// Simple Analytics Service for event tracking
/// 
/// Basic implementation without external dependencies.
/// In production, could integrate with Firebase Analytics, Mixpanel, etc.
/// 
/// Tracked events:
/// - Screen views
/// - Important user actions
/// - Engagement metrics
/// - Dwell times
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Flag to enable/disable logging in debug
  static const bool _debugMode = kDebugMode;

  /// Stores events in memory (for debug/demo)
  final List<AnalyticsEvent> _events = [];

  /// Start timestamp of each screen (to measure dwell time)
  final Map<String, DateTime> _screenStartTimes = {};

  // ============================================================
  // SCREEN VIEWS
  // ============================================================

  /// Tracks screen view
  static void trackScreenView(String screenName) {
    _instance._logEvent('screen_view', {'screen': screenName});
    _instance._screenStartTimes[screenName] = DateTime.now();
  }

  /// Tracks screen exit (to calculate dwell time)
  static void trackScreenExit(String screenName) {
    if (_instance._screenStartTimes.containsKey(screenName)) {
      final startTime = _instance._screenStartTimes[screenName]!;
      final duration = DateTime.now().difference(startTime);
      
      _instance._logEvent('screen_exit', {
        'screen': screenName,
        'duration_seconds': duration.inSeconds,
      });
      
      _instance._screenStartTimes.remove(screenName);
    }
  }

  // ============================================================
  // CUSTOM EVENTS
  // ============================================================

  /// Tracks generic event
  static void trackEvent(String eventName, Map<String, dynamic> parameters) {
    _instance._logEvent(eventName, parameters);
  }

  // ============================================================
  // ONBOARDING EVENTS
  // ============================================================

  /// Tracks onboarding start
  static void trackOnboardingStarted() {
    _instance._logEvent('onboarding_started', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks simplified onboarding completion
  static void trackOnboardingCompleted({
    required int daysToComplete,
    required int stepsCompleted,
  }) {
    _instance._logEvent('onboarding_completed', {
      'days_to_complete': daysToComplete,
      'steps_completed': stepsCompleted,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks onboarding step
  static void trackOnboardingStep(int stepNumber, String stepName) {
    _instance._logEvent('onboarding_step', {
      'step_number': stepNumber,
      'step_name': stepName,
    });
  }

  // ============================================================
  // GOAL EVENTS
  // ============================================================

  /// Tracks goal creation
  static void trackGoalCreated({
    required String goalType,
    required double targetAmount,
    required bool hasDeadline,
    required String creationMethod, // 'wizard' or 'manual'
  }) {
    _instance._logEvent('goal_created', {
      'type': goalType,
      'target_amount': targetAmount,
      'has_deadline': hasDeadline,
      'creation_method': creationMethod,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks goal completion
  static void trackGoalCompleted({
    required String goalType,
    required int daysToComplete,
    required double finalAmount,
  }) {
    _instance._logEvent('goal_completed', {
      'type': goalType,
      'days_to_complete': daysToComplete,
      'final_amount': finalAmount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks goal deletion
  static void trackGoalDeleted(String goalType) {
    _instance._logEvent('goal_deleted', {
      'type': goalType,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // MISSION EVENTS
  // ============================================================

  /// Tracks mission view
  static void trackMissionViewed(String missionId, String missionType) {
    _instance._logEvent('mission_viewed', {
      'mission_id': missionId,
      'mission_type': missionType,
    });
  }

  /// Tracks mission recommendations loading
  static void trackMissionRecommendationsLoaded({required int count}) {
    _instance._logEvent('mission_recommendations_loaded', {
      'count': count,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks interaction with recommended cards
  static void trackMissionRecommendationSwiped({
    required String missionId,
    required String missionType,
    required int position,
  }) {
    _instance._logEvent('mission_recommendation_swiped', {
      'mission_id': missionId,
      'mission_type': missionType,
      'position': position,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks detailed view of recommendation
  static void trackMissionRecommendationDetail({
    required String missionId,
    required String missionType,
    required int position,
    required String source,
  }) {
    _instance._logEvent('mission_recommendation_detail', {
      'mission_id': missionId,
      'mission_type': missionType,
      'position': position,
      'source': source,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks opening of collections (category/goal)
  static void trackMissionCollectionViewed({
    required String collectionType,
    required int targetId,
    required int missionCount,
  }) {
    _instance._logEvent('mission_collection_viewed', {
      'collection_type': collectionType,
      'target_id': targetId,
      'mission_count': missionCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks context analysis snapshot
  static void trackMissionContextSnapshot({
    required int indicatorCount,
    required int opportunityCount,
    required bool fromRefresh,
  }) {
    _instance._logEvent('mission_context_snapshot', {
      'indicators': indicatorCount,
      'opportunities': opportunityCount,
      'from_refresh': fromRefresh,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks manual analysis refresh request
  static void trackMissionContextRefreshRequested() {
    _instance._logEvent('mission_context_refresh_requested', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks mission completion
  static void trackMissionCompleted({
    required String missionId,
    required String missionType,
    required int xpEarned,
  }) {
    _instance._logEvent('mission_completed', {
      'mission_id': missionId,
      'mission_type': missionType,
      'xp_earned': xpEarned,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // SOCIAL EVENTS (FRIENDS)
  // ============================================================

  /// Tracks friend addition
  static void trackFriendAdded({required String method}) {
    _instance._logEvent('friend_added', {
      'method': method, // 'search', 'qr_code', 'suggestion'
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks friend removal
  static void trackFriendRemoved() {
    _instance._logEvent('friend_removed', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks leaderboard view
  static void trackLeaderboardViewed({required int friendsCount}) {
    _instance._logEvent('leaderboard_viewed', {
      'friends_count': friendsCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // TRANSACTION EVENTS
  // ============================================================

  /// Tracks transaction creation
  static void trackTransactionCreated({
    required String type, // 'income' or 'expense'
    required double amount,
    required String category,
    required bool isRecurrent,
  }) {
    _instance._logEvent('transaction_created', {
      'type': type,
      'amount': amount,
      'category': category,
      'is_recurrent': isRecurrent,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks transaction edit
  static void trackTransactionEdited({
    required String type,
    required String category,
  }) {
    _instance._logEvent('transaction_edited', {
      'type': type,
      'category': category,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Tracks transaction deletion
  static void trackTransactionDeleted({
    required String type,
    required double amount,
  }) {
    _instance._logEvent('transaction_deleted', {
      'type': type,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // EVENTOS DE ENGAJAMENTO
  // ============================================================

  /// Rastreia login do usuário
  static void trackLogin({required String method}) {
    _instance._logEvent('user_login', {
      'method': method, // 'email', 'google', etc
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rastreia logout do usuário
  static void trackLogout() {
    _instance._logEvent('user_logout', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rastreia registro de novo usuário
  static void trackSignup({required String method}) {
    _instance._logEvent('user_signup', {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rastreia atualização de perfil
  static void trackProfileUpdated() {
    _instance._logEvent('profile_updated', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // EVENTOS DE ERRO
  // ============================================================

  /// Rastreia erro na aplicação
  static void trackError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
  }) {
    _instance._logEvent('app_error', {
      'error_type': errorType,
      'error_message': errorMessage,
      'stack_trace': stackTrace,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // MÉTODOS INTERNOS
  // ============================================================

  /// Loga evento (implementação interna)
  void _logEvent(String eventName, Map<String, dynamic> parameters) {
    final event = AnalyticsEvent(
      name: eventName,
      parameters: parameters,
      timestamp: DateTime.now(),
    );

    _events.add(event);

    // Em debug, imprime no console
    if (_debugMode) {
      debugPrint('📊 Analytics: $eventName');
      debugPrint('   Parameters: $parameters');
    }
  }

  // ============================================================
  // MÉTODOS DE UTILIDADE
  // ============================================================

  /// Retorna todos os eventos registrados (para debug/demonstração)
  static List<AnalyticsEvent> getEvents() {
    return List.unmodifiable(_instance._events);
  }

  /// Retorna eventos filtrados por nome
  static List<AnalyticsEvent> getEventsByName(String eventName) {
    return _instance._events
        .where((event) => event.name == eventName)
        .toList();
  }

  /// Retorna contagem de eventos por tipo
  static Map<String, int> getEventCounts() {
    final counts = <String, int>{};
    for (final event in _instance._events) {
      counts[event.name] = (counts[event.name] ?? 0) + 1;
    }
    return counts;
  }

  /// Limpa histórico de eventos (útil para testes)
  static void clearEvents() {
    _instance._events.clear();
    _instance._screenStartTimes.clear();
  }

  /// Retorna tempo total gasto em cada tela
  static Map<String, Duration> getScreenTimes() {
    final times = <String, Duration>{};
    
    // Calcular tempo de telas que ainda estão abertas
    final now = DateTime.now();
    for (final entry in _instance._screenStartTimes.entries) {
      times[entry.key] = now.difference(entry.value);
    }
    
    return times;
  }

  /// Retorna resumo de analytics para debug
  static String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('📊 Analytics Summary');
    buffer.writeln('Total events: ${_instance._events.length}');
    buffer.writeln('');
    buffer.writeln('Event counts:');
    
    final counts = getEventCounts();
    counts.forEach((name, count) {
      buffer.writeln('  $name: $count');
    });
    
    buffer.writeln('');
    buffer.writeln('Screen times:');
    final screenTimes = getScreenTimes();
    screenTimes.forEach((screen, duration) {
      buffer.writeln('  $screen: ${duration.inSeconds}s');
    });
    
    return buffer.toString();
  }
}

/// Modelo de evento de analytics
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'AnalyticsEvent(name: $name, parameters: $parameters, timestamp: $timestamp)';
  }

  /// Converte para JSON (útil para envio ao backend)
  Map<String, dynamic> toJson() {
    return {
      'event_name': name,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
