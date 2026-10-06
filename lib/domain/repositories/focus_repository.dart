import '../entities/focus_session.dart';

/// Storage for completed focus sessions.
abstract class FocusRepository {
  /// Saves (or replaces) a session. Idempotent per [FocusSession.id].
  Future<FocusSession> saveSession(FocusSession session);

  /// Sessions that started at or after [since], newest first.
  Future<List<FocusSession>> getSessions(String userId, {DateTime? since});
}
