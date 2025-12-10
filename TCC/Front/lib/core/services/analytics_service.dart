import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const bool _debugMode = kDebugMode;

  final List<AnalyticsEvent> _events = [];

  final Map<String, DateTime> _screenStartTimes = {};


  static void trackScreenView(String screenName) {
    _instance._logEvent('screen_view', {'screen': screenName});
    _instance._screenStartTimes[screenName] = DateTime.now();
  }

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


  static void trackEvent(String eventName, Map<String, dynamic> parameters) {
    _instance._logEvent(eventName, parameters);
  }


  static void trackOnboardingStarted() {
    _instance._logEvent('onboarding_started', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

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

  static void trackOnboardingStep(int stepNumber, String stepName) {
    _instance._logEvent('onboarding_step', {
      'step_number': stepNumber,
      'step_name': stepName,
    });
  }



  static void trackMissionViewed(String missionId, String missionType) {
    _instance._logEvent('mission_viewed', {
      'mission_id': missionId,
      'mission_type': missionType,
    });
  }

  static void trackMissionRecommendationsLoaded({required int count}) {
    _instance._logEvent('mission_recommendations_loaded', {
      'count': count,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

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

  static void trackMissionCollectionViewed({
    required String collectionType,
    required Object targetId,
    required int missionCount,
  }) {
    _instance._logEvent('mission_collection_viewed', {
      'collection_type': collectionType,
      'target_id': targetId.toString(),
      'mission_count': missionCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

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

  static void trackMissionContextRefreshRequested() {
    _instance._logEvent('mission_context_refresh_requested', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

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


  static void trackTransactionCreated({
    required String type,
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


  static void trackLogin({required String method}) {
    _instance._logEvent('user_login', {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackLogout() {
    _instance._logEvent('user_logout', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackSignup({required String method}) {
    _instance._logEvent('user_signup', {
      'method': method,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackProfileUpdated() {
    _instance._logEvent('profile_updated', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }


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


  void _logEvent(String eventName, Map<String, dynamic> parameters) {
    final event = AnalyticsEvent(
      name: eventName,
      parameters: parameters,
      timestamp: DateTime.now(),
    );

    _events.add(event);

    if (_debugMode) {
      debugPrint('📊 Analytics: $eventName');
      debugPrint('   Parameters: $parameters');
    }
  }


  static List<AnalyticsEvent> getEvents() {
    return List.unmodifiable(_instance._events);
  }

  static List<AnalyticsEvent> getEventsByName(String eventName) {
    return _instance._events
        .where((event) => event.name == eventName)
        .toList();
  }

  static Map<String, int> getEventCounts() {
    final counts = <String, int>{};
    for (final event in _instance._events) {
      counts[event.name] = (counts[event.name] ?? 0) + 1;
    }
    return counts;
  }

  static void clearEvents() {
    _instance._events.clear();
    _instance._screenStartTimes.clear();
  }

  static Map<String, Duration> getScreenTimes() {
    final times = <String, Duration>{};
    
    final now = DateTime.now();
    for (final entry in _instance._screenStartTimes.entries) {
      times[entry.key] = now.difference(entry.value);
    }
    
    return times;
  }

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

  Map<String, dynamic> toJson() {
    return {
      'event_name': name,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
