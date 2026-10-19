import '../../entities/focus_session.dart';
import '../../entities/life_event.dart';
import '../../focus/focus_event_sink.dart';
import 'pulse_service.dart';

/// Records every finished focus block as a `focus` moment on the OmniPulse
/// timeline, with the minutes actually focused.
///
/// The [PulseService] is resolved on each call so the sink can be created
/// before the Pulse stack exists.
class PulseFocusEventSink implements FocusEventSink {
  PulseFocusEventSink(this._service);

  final PulseService Function() _service;

  @override
  Future<void> onFocusCompleted(FocusSession session) async {
    if (session.userId.isEmpty) return;
    await _service().log(
      session.userId,
      LifeEventType.focus,
      at: session.endedAt,
      metadata: {
        'minutes': session.focusedMinutes,
        'plannedMinutes': (session.plannedSeconds / 60).round(),
        'sessionId': session.id,
      },
    );
  }
}
