import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Event names used across the app. Keep them in snake_case and free of
/// user content.
abstract final class AnalyticsEvents {
  static const signUp = 'sign_up';
  static const login = 'login';
  static const taskCreated = 'task_created';
  static const taskCompleted = 'task_completed';
  static const noteCreated = 'note_created';
  static const habitCompleted = 'habit_completed';
  static const transactionAdded = 'transaction_added';
  static const focusSessionCompleted = 'focus_session_completed';
}

/// Removes anything that could identify a person or carry their content
/// before an event leaves the device.
abstract final class AnalyticsSanitizer {
  static final _eventName = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,39}$');
  static final _safeString = RegExp(r'^[A-Za-z0-9_.\-]{1,40}$');
  static const _maxParams = 25;

  /// Parameter names containing any of these fragments are dropped.
  static const blockedKeyFragments = <String>[
    'email',
    'mail',
    'title',
    'name',
    'amount',
    'price',
    'balance',
    'description',
    'note',
    'content',
    'body',
    'text',
    'password',
    'phone',
    'address',
    'token',
    'uid',
    'user_id',
    'location',
  ];

  static bool isValidEventName(String name) => _eventName.hasMatch(name);

  static Map<String, Object> sanitize(Map<String, Object?>? params) {
    final out = <String, Object>{};
    if (params == null) return out;
    for (final entry in params.entries) {
      if (out.length >= _maxParams) break;
      final key = entry.key.toLowerCase();
      if (!_eventName.hasMatch(entry.key)) continue;
      if (blockedKeyFragments.any(key.contains)) continue;
      final value = entry.value;
      if (value is bool) {
        out[entry.key] = value ? 1 : 0;
      } else if (value is int || value is double) {
        out[entry.key] = value!;
      } else if (value is String && _safeString.hasMatch(value)) {
        out[entry.key] = value;
      }
    }
    return out;
  }
}

/// Product analytics. Other features call [AnalyticsService.instance] and
/// never touch Firebase directly. Never pass PII (emails, titles, amounts).
abstract class AnalyticsService {
  /// Process-wide instance. A no-op until telemetry bootstrap swaps in the
  /// Firebase implementation, so calls are always safe (tests, web, debug).
  static AnalyticsService instance = const NoopAnalyticsService();

  Future<void> logEvent(String name, [Map<String, Object?>? params]);
  Future<void> setUserId(String? uid);
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? params]) async {}

  @override
  Future<void> setUserId(String? uid) async {}
}

/// Records every event in memory; used by tests.
class RecordingAnalyticsService implements AnalyticsService {
  final events = <({String name, Map<String, Object> params})>[];
  String? userId;

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? params]) async {
    if (!AnalyticsSanitizer.isValidEventName(name)) return;
    events.add((name: name, params: AnalyticsSanitizer.sanitize(params)));
  }

  @override
  Future<void> setUserId(String? uid) async => userId = uid;
}

/// [AnalyticsService] backed by `firebase_analytics`. Works on Android, iOS
/// and web; every call is guarded so a missing Firebase app never throws.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalytics? get _analytics {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? params]) async {
    if (!AnalyticsSanitizer.isValidEventName(name)) return;
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: AnalyticsSanitizer.sanitize(params),
      );
    } catch (_) {}
  }

  @override
  Future<void> setUserId(String? uid) async {
    try {
      await _analytics?.setUserId(id: uid);
    } catch (_) {}
  }
}
