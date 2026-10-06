import '../../entities/life_event.dart';
import 'daily_facts.dart';
import 'sleep_analyzer.dart';

enum TimelineKind {
  sleep,
  wake,
  meal,
  water,
  workout,
  focus,
  mood,
  energy,
  habit,
  task,
  note,
  custom,
}

class TimelineEntry {
  const TimelineEntry({
    required this.time,
    required this.kind,
    required this.title,
    this.detail,
    this.eventId,
  });

  /// Null for items that belong to the day but have no recorded time
  /// (habit check-offs only store the date).
  final DateTime? time;
  final TimelineKind kind;
  final String title;
  final String? detail;

  /// The editable [LifeEvent] behind this entry, if any. Tasks and habits
  /// come from their own modules and are not editable here.
  final String? eventId;

  bool get isEditable => eventId != null;
}

class CompletedTaskFact {
  const CompletedTaskFact(this.title, this.completedAt);
  final String title;
  final DateTime completedAt;
}

String moodLabel(int score) => switch (score) {
  1 => 'Very low',
  2 => 'Low',
  3 => 'Okay',
  4 => 'Good',
  _ => 'Great',
};

String energyLabel(int level) => switch (level) {
  1 => 'Very low',
  2 => 'Low',
  3 => 'Okay',
  4 => 'High',
  _ => 'Very high',
};

String formatDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Merges everything recorded on one day, from every source, into a single
/// chronological list. Task completions and habit check-offs are read
/// from their own modules (never duplicated as events).
class TimelineBuilder {
  const TimelineBuilder({this.sleepAnalyzer = const SleepAnalyzer()});

  final SleepAnalyzer sleepAnalyzer;

  List<TimelineEntry> forDay(
    DateTime day, {
    required Iterable<LifeEvent> events,
    Iterable<CompletedTaskFact> completedTasks = const [],
    Iterable<String> habitsDone = const [],
  }) {
    final d = dayOf(day);
    final sessions = sleepAnalyzer.sessions(events);
    final durationByWakeId = {
      for (final s in sessions) s.endEventId: s.duration,
    };

    final dayEvents = events.where((e) => dayOf(e.timestamp) == d).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final entries = <TimelineEntry>[];
    final waterByHour = <int, List<LifeEvent>>{};

    for (final e in dayEvents) {
      switch (e.type) {
        case LifeEventType.water:
          waterByHour.putIfAbsent(e.timestamp.hour, () => []).add(e);
        case LifeEventType.sleepStart:
          entries.add(_entry(e, TimelineKind.sleep, 'Sleep'));
        case LifeEventType.wake:
          final dur = durationByWakeId[e.id];
          entries.add(
            _entry(
              e,
              TimelineKind.wake,
              'Wake',
              detail: dur == null ? null : 'Slept ${formatDuration(dur)}',
            ),
          );
        case LifeEventType.meal:
          entries.add(
            _entry(
              e,
              TimelineKind.meal,
              _capitalise(e.metadata['kind'] as String?) ?? 'Meal',
            ),
          );
        case LifeEventType.workout:
          final minutes = e.metadata['minutes'];
          entries.add(
            _entry(
              e,
              TimelineKind.workout,
              'Workout',
              detail: minutes is num ? '${minutes.toInt()} min' : null,
            ),
          );
        case LifeEventType.focus:
          final minutes = e.metadata['minutes'];
          entries.add(
            _entry(
              e,
              TimelineKind.focus,
              'Focus',
              detail: minutes is num ? '${minutes.toInt()} min' : null,
            ),
          );
        case LifeEventType.mood:
          final s = e.moodScore;
          entries.add(
            _entry(
              e,
              TimelineKind.mood,
              s == null ? 'Mood' : 'Mood: ${moodLabel(s)}',
            ),
          );
        case LifeEventType.energy:
          final l = e.energyLevel;
          entries.add(
            _entry(
              e,
              TimelineKind.energy,
              l == null ? 'Energy' : 'Energy: ${energyLabel(l)}',
            ),
          );
        case LifeEventType.note:
          entries.add(_entry(e, TimelineKind.note, 'Note', detail: e.label));
        case LifeEventType.custom:
          entries.add(_entry(e, TimelineKind.custom, e.label ?? 'Moment'));
        case LifeEventType.habit:
        case LifeEventType.taskCompleted:
          // Shown from the habit/task modules to avoid duplicates.
          break;
      }
    }

    for (final hour in waterByHour.keys) {
      final group = waterByHour[hour]!;
      final ml = group.fold<int>(
        0,
        (s, e) => s + ((e.metadata['ml'] as num?)?.toInt() ?? 250),
      );
      entries.add(
        TimelineEntry(
          time: group.first.timestamp,
          kind: TimelineKind.water,
          title: group.length == 1 ? 'Water' : 'Water x${group.length}',
          detail: '$ml ml',
          eventId: group.length == 1 ? group.first.id : null,
        ),
      );
    }

    for (final t in completedTasks) {
      if (dayOf(t.completedAt) == d) {
        entries.add(
          TimelineEntry(
            time: t.completedAt,
            kind: TimelineKind.task,
            title: 'Task completed',
            detail: t.title,
          ),
        );
      }
    }

    entries.sort((a, b) => a.time!.compareTo(b.time!));

    for (final h in habitsDone) {
      entries.add(
        TimelineEntry(
          time: null,
          kind: TimelineKind.habit,
          title: 'Habit',
          detail: h,
        ),
      );
    }
    return entries;
  }

  TimelineEntry _entry(
    LifeEvent e,
    TimelineKind kind,
    String title, {
    String? detail,
  }) => TimelineEntry(
    time: e.timestamp,
    kind: kind,
    title: title,
    detail: detail,
    eventId: e.id,
  );

  String? _capitalise(String? s) =>
      s == null || s.isEmpty ? null : s[0].toUpperCase() + s.substring(1);
}
