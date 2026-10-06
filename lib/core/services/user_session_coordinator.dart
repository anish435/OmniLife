import 'analytics_service.dart';
import 'crash_reporter.dart';
import 'push_registration_manager.dart';

/// Fans sign-in and sign-out out to analytics, crash reporting and push
/// registration, so [AuthController] needs only one call per transition.
class UserSessionCoordinator {
  static UserSessionCoordinator instance = UserSessionCoordinator();

  PushRegistrationManager? push;

  /// Called whenever the signed-in user changes. [uid] is null on sign-out.
  void onUserChanged(String? uid) {
    // Only a one-way hash of the uid is ever sent to third-party tools.
    AnalyticsService.instance.setUserId(uid == null ? null : hashedUserId(uid));
    CrashReporter.instance.setUser(uid);
    if (uid != null) {
      push?.onSignedIn(uid);
    }
  }

  /// Called before sign-out, while Firestore is still writable as the user.
  Future<void> beforeSignOut(String? uid) async {
    if (uid == null) return;
    try {
      await push?.onBeforeSignOut(uid).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
