import 'package:flutter/foundation.dart';

/// Serviço simples de Analytics para rastreamento de eventos (Dia 21-25)
/// 
/// Implementação básica sem dependências externas.
/// Em produção, poderia integrar com Firebase Analytics, Mixpanel, etc.
/// 
/// Eventos rastreados:
/// - Visualizações de tela
/// - Ações importantes do usuário
/// - Métricas de engajamento
/// - Tempos de permanência
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Flag para habilitar/desabilitar logging em debug
  static const bool _debugMode = kDebugMode;

  /// Armazena eventos em memória (para debug/demonstração)
  final List<AnalyticsEvent> _events = [];

  /// Timestamp de início de cada tela (para medir tempo de permanência)
  final Map<String, DateTime> _screenStartTimes = {};

  // ============================================================
  // VISUALIZAÇÕES DE TELA
  // ============================================================

  /// Rastreia visualização de tela
  static void trackScreenView(String screenName) {
    _instance._logEvent('screen_view', {'screen': screenName});
    _instance._screenStartTimes[screenName] = DateTime.now();
  }

  /// Rastreia saída de tela (para calcular tempo de permanência)
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
  // EVENTOS CUSTOMIZADOS
  // ============================================================

  /// Rastreia evento genérico
  static void trackEvent(String eventName, Map<String, dynamic> parameters) {
    _instance._logEvent(eventName, parameters);
  }

  // ============================================================
  // EVENTOS DE ONBOARDING
  // ============================================================

  /// Rastreia início do onboarding
  static void trackOnboardingStarted() {
    _instance._logEvent('onboarding_started', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rastreia conclusão do onboarding simplificado
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

  /// Rastreia etapa do onboarding
  static void trackOnboardingStep(int stepNumber, String stepName) {
    _instance._logEvent('onboarding_step', {
      'step_number': stepNumber,
      'step_name': stepName,
    });
  }

  // ============================================================
  // EVENTOS DE METAS
  // ============================================================

  /// Rastreia criação de meta
  static void trackGoalCreated({
    required String goalType,
    required double targetAmount,
    required bool hasDeadline,
    required String creationMethod, // 'wizard' ou 'manual'
  }) {
    _instance._logEvent('goal_created', {
      'type': goalType,
      'target_amount': targetAmount,
      'has_deadline': hasDeadline,
      'creation_method': creationMethod,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rastreia conclusão de meta
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

  /// Rastreia exclusão de meta
  static void trackGoalDeleted(String goalType) {
    _instance._logEvent('goal_deleted', {
      'type': goalType,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // EVENTOS DE MISSÕES
  // ============================================================

  /// Rastreia visualização de missão
  static void trackMissionViewed(String missionId, String missionType) {
    _instance._logEvent('mission_viewed', {
      'mission_id': missionId,
      'mission_type': missionType,
    });
  }

  /// Rastreia conclusão de missão
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
  // EVENTOS SOCIAIS (AMIGOS)
  // ============================================================

  /// Rastreia adição de amigo
  static void trackFriendAdded({required String method}) {
    _instance._logEvent('friend_added', {
      'method': method, // 'search', 'qr_code', 'suggestion'
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rastreia remoção de amigo
  static void trackFriendRemoved() {
    _instance._logEvent('friend_removed', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Rastreia visualização de ranking
  static void trackLeaderboardViewed({required int friendsCount}) {
    _instance._logEvent('leaderboard_viewed', {
      'friends_count': friendsCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // EVENTOS DE TRANSAÇÕES
  // ============================================================

  /// Rastreia criação de transação
  static void trackTransactionCreated({
    required String type, // 'income' ou 'expense'
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

  /// Rastreia edição de transação
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

  /// Rastreia exclusão de transação
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

    // TODO: Em produção, enviar para backend ou serviço de analytics
    // _sendToBackend(event);
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
