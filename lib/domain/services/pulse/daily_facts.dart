import '../../entities/life_event.dart';
import 'sleep_analyzer.dart';

class EnergyEntry {
  const EnergyEntry(this.hour, this.level);
  final int hour;
  final int level;
}

/// Everything recorded for one local calendar day, from every module.
/// This is the single input to Momentum and Pattern Detection, so those
/// calculators stay pure and every number can be traced to recorded data.
class DailyFacts {
  DailyFacts(this.day);

  final DateTime day;
  int tasksCompleted = 0;
  int tasksDue = 0;
  int habitsDone = 0;
  int habitsScheduled = 0;
  int focusSessions = 0;
  int focusMinutes = 0;
  int workouts = 0;
  int workoutMinutes = 0;
  int waterMl = 0;
  int meals = 0;
  int? sleepMinutes;
  int? bedtimeMinutesFromNoon;
  final List<int> moodScores = [];
  final List<EnergyEntry> energyEntries = [];

  int get checkIns => moodScores.length + energyEntries.length;

  double? get averageMood => moodScores.isEmpty
      ? null
      : moodScores.reduce((a, b) => a + b) / moodScores.length;

  double? get averageEnergy => energyEntries.isEmpty
      ? null
      : energyEntries.map((e) => e.level).reduce((a, b) => a + b) /
            energyEntries.length;

  double? get habitCompletionRate =>
      habitsScheduled == 0 ? null : habitsDone / habitsScheduled;

  /// Something the user did or logged that day (not merely scheduled).
  bool get hasAction =>
      tasksCompleted > 0 ||
      habitsDone > 0 ||
      focusSessions > 0 ||
      workouts > 0 ||
      checkIns > 0 ||
      sleepMinutes != null ||
      meals > 0 ||
      waterMl > 0;
}

class TaskCompletionFact {
  const TaskCompletionFact(this.completedAt);
  final DateTime completedAt;
}

class HabitDayFact {
  const HabitDayFact({
    required this.day,
    required this.scheduled,
    required this.done,
  });
  final DateTime day;
  final int scheduled;
  final int done;
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

class DailyFactsBuilder {
  const DailyFactsBuilder({this.sleepAnalyzer = const SleepAnalyzer()});

  final SleepAnalyzer sleepAnalyzer;

  /// Builds one [DailyFacts] per day in [from]..[to] inclusive (including
  /// empty days, so averages are over days not over events).
  List<DailyFacts> build({
    required DateTime from,
    required DateTime to,
    required Iterable<LifeEvent> events,
    Iterable<TaskCompletionFact> taskCompletions = const [],
    Iterable<DateTime> taskDueDates = const [],
    Iterable<HabitDayFact> habitDays = const [],
  }) {
    final start = dayOf(from);
    final end = dayOf(to);
    final days = <DateTime, DailyFacts>{};
    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      days[d] = DailyFacts(d);
    }

    for (final t in taskCompletions) {
      days[dayOf(t.completedAt)]?.tasksCompleted++;
    }
    for (final due in taskDueDates) {
      days[dayOf(due)]?.tasksDue++;
    }
    for (final h in habitDays) {
      final f = days[dayOf(h.day)];
      if (f != null) {
        f.habitsScheduled += h.scheduled;
        f.habitsDone += h.done;
      }
    }

    for (final e in events) {
      final f = days[dayOf(e.timestamp)];
      if (f == null) continue;
      switch (e.type) {
        case LifeEventType.focus:
          f.focusSessions++;
          f.focusMinutes += _int(e.metadata['minutes']) ?? 0;
        case LifeEventType.workout:
          f.workouts++;
          f.workoutMinutes += _int(e.metadata['minutes']) ?? 0;
        case LifeEventType.water:
          f.waterMl += _int(e.metadata['ml']) ?? 250;
        case LifeEventType.meal:
          f.meals++;
        case LifeEventType.mood:
          final s = e.moodScore;
          if (s != null) f.moodScores.add(s);
        case LifeEventType.energy:
          final l = e.energyLevel;
          if (l != null) f.energyEntries.add(EnergyEntry(e.timestamp.hour, l));
        // Tasks come from the task repository, not task_completed events,
        // so they are never double counted. Habits likewise. Sleep is
        // derived below from paired events.
        case LifeEventType.sleepStart:
        case LifeEventType.wake:
        case LifeEventType.habit:
        case LifeEventType.taskCompleted:
        case LifeEventType.note:
        case LifeEventType.custom:
          break;
      }
    }

    for (final s in sleepAnalyzer.sessions(events)) {
      final f = days[s.wakeDay];
      if (f != null) {
        // Multiple sessions (naps) on one wake day add up.
        f.sleepMinutes = (f.sleepMinutes ?? 0) + s.duration.inMinutes;
        f.bedtimeMinutesFromNoon ??= s.bedtimeMinutesFromNoon;
      }
    }

    return days.values.toList();
  }

  int? _int(Object? v) => v is num ? v.toInt() : null;
}
