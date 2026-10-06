import '../entities/focus_session.dart';

/// Hook for recording a completed focus session as a life event elsewhere
/// (for example the OmniPulse timeline). The default does nothing; the app
/// shell registers a real implementation with `Get.put<FocusEventSink>(...)`.
abstract class FocusEventSink {
  Future<void> onFocusCompleted(FocusSession session);
}

class NoopFocusEventSink implements FocusEventSink {
  const NoopFocusEventSink();

  @override
  Future<void> onFocusCompleted(FocusSession session) async {}
}
