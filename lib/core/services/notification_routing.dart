import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../presentation/controllers/auth_controller.dart';

/// Where a tapped notification should take the user.
@immutable
class NotificationTarget {
  const NotificationTarget(this.route, {this.id, this.kind});

  final String route;

  /// Optional entity id (task id, habit id, event id) passed as arguments.
  final String? id;
  final String? kind;

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget &&
      other.route == route &&
      other.id == id &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(route, id, kind);

  @override
  String toString() => 'NotificationTarget($route, id: $id)';
}

/// Converts local-notification payloads and FCM data maps into routes.
///
/// Payload format: `kind` or `kind:id`, for example `task:abc123`, `focus`.
/// Legacy payloads that are a bare entity id (`task_...`, `event_...`) are
/// still understood. Only a fixed allow-list of routes is reachable, so a
/// crafted push cannot open arbitrary screens such as login.
abstract final class NotificationRouting {
  static const kindTask = 'task';
  static const kindHabit = 'habit';
  static const kindCalendar = 'calendar';
  static const kindFocus = 'focus';
  static const kindNote = 'note';

  static const Map<String, String> _routes = {
    kindTask: AppRoutes.tasks,
    kindHabit: AppRoutes.habits,
    kindCalendar: AppRoutes.calendar,
    'event': AppRoutes.calendar,
    kindFocus: AppRoutes.focus,
    kindNote: AppRoutes.notes,
  };

  static String encode(String kind, [String? id]) =>
      id == null || id.isEmpty ? kind : '$kind:$id';

  static NotificationTarget? fromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    final p = payload.trim();
    final colon = p.indexOf(':');
    if (colon > 0) {
      final kind = p.substring(0, colon);
      final id = p.substring(colon + 1);
      return _build(kind, id.isEmpty ? null : id);
    }
    if (_routes.containsKey(p)) return _build(p, null);
    // Legacy bare ids.
    for (final kind in const [kindTask, kindHabit, 'event', kindNote]) {
      if (p.startsWith('${kind}_')) return _build(kind, p);
    }
    if (p.startsWith('demo_event')) return _build(kindCalendar, p);
    return null;
  }

  /// FCM `data` maps use `route` (a kind or a known route name) or `type`,
  /// plus an optional `id`.
  static NotificationTarget? fromData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    final id = data['id']?.toString();
    final raw = (data['route'] ?? data['type'] ?? data['kind'])?.toString();
    if (raw == null || raw.isEmpty) {
      return fromPayload(data['payload']?.toString());
    }
    final key = raw.startsWith('/') ? raw.substring(1) : raw;
    if (_routes.containsKey(key)) return _build(key, id);
    // Allow the plural route names (/tasks, /habits).
    for (final entry in _routes.entries) {
      if (entry.value == raw) return _build(entry.key, id);
    }
    return null;
  }

  static NotificationTarget? _build(String kind, String? id) {
    final route = _routes[kind];
    if (route == null) return null;
    return NotificationTarget(route, id: id, kind: kind);
  }
}

/// Navigates to a [NotificationTarget], deferring until the user is signed in
/// and the navigator is mounted. This covers cold starts from a terminated
/// state, where the tap arrives before the login/dashboard flow finishes.
class NotificationNavigator {
  NotificationNavigator({
    bool Function()? isReady,
    void Function(String route, Object? arguments)? navigate,
    String Function()? currentRoute,
  }) : _isReady = isReady ?? _defaultIsReady,
       _navigate = navigate ?? _defaultNavigate,
       _currentRoute = currentRoute ?? (() => Get.currentRoute);

  static NotificationNavigator instance = NotificationNavigator();

  final bool Function() _isReady;
  final void Function(String route, Object? arguments) _navigate;
  final String Function() _currentRoute;

  NotificationTarget? _pending;
  Timer? _poll;

  NotificationTarget? get pending => _pending;

  static bool _defaultIsReady() {
    try {
      if (Get.key.currentState == null) return false;
      if (!Get.isRegistered<AuthController>()) return false;
      final auth = Get.find<AuthController>();
      return auth.status.value == AuthStatus.authenticated &&
          Get.currentRoute != AppRoutes.splash &&
          Get.currentRoute != AppRoutes.login;
    } catch (_) {
      return false;
    }
  }

  static void _defaultNavigate(String route, Object? arguments) =>
      Get.toNamed(route, arguments: arguments);

  /// Opens [target] now, or remembers it until the app is ready.
  void handle(NotificationTarget? target) {
    if (target == null) return;
    if (_isReady()) {
      _open(target);
    } else {
      _pending = target;
      _watchAuth();
    }
  }

  /// Opens a remembered target if the app is ready. Returns true if opened.
  bool flushPending() {
    final target = _pending;
    if (target == null || !_isReady()) return false;
    _pending = null;
    _open(target);
    return true;
  }

  void _open(NotificationTarget target) {
    if (_currentRoute() == target.route) return;
    _navigate(target.route, target.id);
  }

  /// Polls briefly for readiness (sign-in plus the dashboard redirect) rather
  /// than relying on a single auth event, which may already have fired.
  void _watchAuth() {
    if (_poll != null) return;
    var ticks = 0;
    _poll = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      ticks++;
      if (flushPending() || _pending == null || ticks > 60) {
        timer.cancel();
        _poll = null;
      }
    });
  }
}
