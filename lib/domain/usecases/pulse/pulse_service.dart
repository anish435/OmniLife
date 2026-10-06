// Dependencies are held under private names so call sites cannot reach
// into the service; the named-parameter API keeps construction readable.
// ignore_for_file: prefer_initializing_formals

import '../../entities/life_event.dart';
import '../../repositories/life_event_repository.dart';
import '../../services/pulse/sleep_analyzer.dart';

class QuickLogResult {
  const QuickLogResult({
    required this.event,
    this.sleepDuration,
    this.alreadyAsleep = false,
  });

  /// The recorded (or, for a repeated Sleep tap, the existing) event.
  final LifeEvent event;

  /// Set when a Wake tap closed an open sleep: the calculated duration.
  final Duration? sleepDuration;

  /// True when Sleep was tapped while a sleep was already open, so no
  /// duplicate was created.
  final bool alreadyAsleep;
}

/// One-tap OmniPulse capture. Nothing here asks for detail: every method
/// records immediately and returns what happened so the UI can confirm
/// and offer Undo. Details can be added afterwards by editing the event.
class PulseService {
  PulseService({
    required LifeEventRepository events,
    SleepAnalyzer analyzer = const SleepAnalyzer(),
    DateTime Function()? now,
  }) : _events = events,
       _analyzer = analyzer,
       _now = now ?? DateTime.now;

  final LifeEventRepository _events;
  final SleepAnalyzer _analyzer;
  final DateTime Function() _now;

  Future<QuickLogResult> log(
    String uid,
    LifeEventType type, {
    Map<String, dynamic> metadata = const {},
    DateTime? at,
  }) async {
    final event = await _events.record(
      uid,
      type,
      at: at,
      metadata: _withDefaults(type, metadata, at ?? _now()),
    );
    return QuickLogResult(event: event);
  }

  /// "Sleep": records bedtime. A second tap while already asleep does not
  /// create a duplicate.
  Future<QuickLogResult> startSleep(String uid) async {
    final open = await openSleep(uid);
    if (open != null) {
      return QuickLogResult(event: open, alreadyAsleep: true);
    }
    return log(uid, LifeEventType.sleepStart);
  }

  /// "Wake": records the wake time and, when a sleep is open, calculates
  /// the duration automatically.
  Future<QuickLogResult> wake(String uid) async {
    final now = _now();
    final open = await openSleep(uid);
    final duration = open == null ? null : now.difference(open.timestamp);
    final event = await _events.record(
      uid,
      LifeEventType.wake,
      at: now,
      metadata: {
        if (duration != null) 'durationMinutes': duration.inMinutes,
        if (open != null) 'sleepStartId': open.id,
      },
    );
    return QuickLogResult(event: event, sleepDuration: duration);
  }

  /// The sleep currently in progress, if any.
  Future<LifeEvent?> openSleep(String uid) async {
    final now = _now();
    final recent = await _events.range(
      uid,
      now.subtract(const Duration(hours: 24)),
      now.add(const Duration(minutes: 1)),
    );
    return _analyzer.openSleep(recent, now: now);
  }

  Future<void> undo(LifeEvent event) => _events.delete(event);

  /// Optional detail added after the fact; the event already exists.
  Future<LifeEvent> addDetail(LifeEvent event, Map<String, dynamic> metadata) =>
      _events.update(
        event.copyWith(metadata: {...event.metadata, ...metadata}),
      );

  Future<LifeEvent> correctTime(LifeEvent event, DateTime timestamp) =>
      _events.update(event.copyWith(timestamp: timestamp));

  Map<String, dynamic> _withDefaults(
    LifeEventType type,
    Map<String, dynamic> metadata,
    DateTime at,
  ) {
    switch (type) {
      case LifeEventType.water:
        return {'ml': 250, ...metadata};
      case LifeEventType.meal:
        return {'kind': _mealKind(at), ...metadata};
      default:
        return metadata;
    }
  }

  /// A sensible guess the user can edit; saves a tap.
  String _mealKind(DateTime at) {
    final h = at.hour;
    if (h < 11) return 'breakfast';
    if (h < 16) return 'lunch';
    if (h < 21) return 'dinner';
    return 'snack';
  }
}
