// Dependencies are held under private names so call sites cannot reach
// into the service; the named-parameter API keeps construction readable.
// ignore_for_file: prefer_initializing_formals

import '../../entities/habit.dart';
import '../../repositories/habit_repository.dart';
import '../../repositories/life_event_repository.dart';
import '../../repositories/task_repository.dart';
import '../../services/pulse/daily_facts.dart';
import '../../services/pulse/day_replay.dart';
import '../../services/pulse/momentum_calculator.dart';
import '../../services/pulse/pattern_detector.dart';
import '../../services/pulse/sleep_analyzer.dart';
import '../../services/pulse/timeline_builder.dart';

class PulseInsights {
  const PulseInsights({
    required this.days,
    required this.sessions,
    required this.sleep,
    required this.momentum,
    required this.patterns,
    required this.hasAnyData,
  });

  final List<DailyFacts> days;
  final List<SleepSession> sessions;
  final SleepSummary sleep;
  final MomentumReport momentum;
  final List<LifePattern> patterns;
  final bool hasAnyData;
}

class DayView {
  const DayView({
    required this.day,
    required this.timeline,
    required this.replay,
    required this.facts,
  });

  final DateTime day;
  final List<TimelineEntry> timeline;
  final DayReplay replay;
  final DailyFacts facts;
}

/// Gathers a user's recorded data from every module (life events, tasks,
/// habits) and runs it through the pure OmniPulse calculators. This is the
/// one place module data is combined, so the AI tools and the UI see
/// exactly the same numbers.
class PulseInsightsService {
  PulseInsightsService({
    required LifeEventRepository events,
    required TaskRepository tasks,
    required HabitRepository habits,
    DailyFactsBuilder factsBuilder = const DailyFactsBuilder(),
    MomentumCalculator momentum = const MomentumCalculator(),
    PatternDetector patterns = const PatternDetector(),
    SleepAnalyzer sleep = const SleepAnalyzer(),
    TimelineBuilder timeline = const TimelineBuilder(),
    DayReplayBuilder replay = const DayReplayBuilder(),
    DateTime Function()? now,
  }) : _events = events,
       _tasks = tasks,
       _habits = habits,
       _factsBuilder = factsBuilder,
       _momentum = momentum,
       _patterns = patterns,
       _sleep = sleep,
       _timeline = timeline,
       _replay = replay,
       _now = now ?? DateTime.now;

  final LifeEventRepository _events;
  final TaskRepository _tasks;
  final HabitRepository _habits;
  final DailyFactsBuilder _factsBuilder;
  final MomentumCalculator _momentum;
  final PatternDetector _patterns;
  final SleepAnalyzer _sleep;
  final TimelineBuilder _timeline;
  final DayReplayBuilder _replay;
  final DateTime Function() _now;

  /// Momentum, patterns and sleep trends over the last [days] days
  /// (at least 28 so each metric has a previous window to compare to).
  Future<PulseInsights> load(String uid, {int days = 60}) async {
    final today = dayOf(_now());
    final from = today.subtract(Duration(days: days - 1));
    final to = today.add(const Duration(days: 1));

    final events = await _events.range(
      uid,
      from.subtract(const Duration(days: 1)),
      to,
    );
    final sources = await _taskAndHabitFacts(uid, from, today);
    final facts = _factsBuilder.build(
      from: from,
      to: today,
      events: events,
      taskCompletions: sources.completions,
      taskDueDates: sources.dueDates,
      habitDays: sources.habitDays,
    );
    final sessions = _sleep.sessions(events);
    return PulseInsights(
      days: facts,
      sessions: sessions,
      sleep: _sleep.summarize(sessions, now: _now()),
      momentum: _momentum.compute(facts),
      patterns: _patterns.detect(facts),
      hasAnyData: facts.any((d) => d.hasAction),
    );
  }

  /// Timeline and replay for one calendar day.
  Future<DayView> dayView(String uid, DateTime day) async {
    final d = dayOf(day);
    final next = DateTime(d.year, d.month, d.day + 1);
    final events = await _events.range(
      uid,
      d.subtract(const Duration(days: 1)),
      next,
    );
    final sources = await _taskAndHabitFacts(uid, d, d);
    final facts = _factsBuilder
        .build(
          from: d,
          to: d,
          events: events,
          taskCompletions: sources.completions,
          taskDueDates: sources.dueDates,
          habitDays: sources.habitDays,
        )
        .single;
    final timeline = _timeline.forDay(
      d,
      events: events,
      completedTasks: sources.completedTasks.where(
        (t) => dayOf(t.completedAt) == d,
      ),
      habitsDone: sources.habitTitlesDoneOn(d),
    );
    return DayView(
      day: d,
      timeline: timeline,
      replay: _replay.build(d, facts: facts, sessions: _sleep.sessions(events)),
      facts: facts,
    );
  }

  Future<_Sources> _taskAndHabitFacts(
    String uid,
    DateTime from,
    DateTime to,
  ) async {
    final tasks = await _tasks.getTasks(uid);
    final completed = tasks
        .where((t) => t.completed)
        .map((t) => CompletedTaskFact(t.title, t.updatedAt))
        .toList();
    final dueDates = tasks.map((t) => t.dueDate).whereType<DateTime>().toList();

    final habits = await _habits.getHabits(uid);
    final habitDays = <HabitDayFact>[];
    final doneTitles = <String, List<String>>{};
    final scheduledByDay = <DateTime, int>{};
    final doneByDay = <DateTime, int>{};

    for (final h in habits) {
      for (
        var d = from;
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        if (_isScheduled(h, d)) {
          scheduledByDay[d] = (scheduledByDay[d] ?? 0) + 1;
        }
      }
      final logs = await _habits.getHabitLogs(h.id);
      for (final log in logs.where((l) => l.isCompleted)) {
        final day = DateTime.tryParse(log.date);
        if (day == null) continue;
        final dd = dayOf(day);
        if (dd.isBefore(from) || dd.isAfter(to)) continue;
        doneByDay[dd] = (doneByDay[dd] ?? 0) + 1;
        doneTitles.putIfAbsent(log.date, () => []).add(h.title);
      }
    }
    for (final d in {...scheduledByDay.keys, ...doneByDay.keys}) {
      habitDays.add(
        HabitDayFact(
          day: d,
          scheduled: scheduledByDay[d] ?? 0,
          done: doneByDay[d] ?? 0,
        ),
      );
    }
    return _Sources(
      completions: completed
          .map((c) => TaskCompletionFact(c.completedAt))
          .toList(),
      completedTasks: completed,
      dueDates: dueDates,
      habitDays: habitDays,
      doneTitlesByDate: doneTitles,
    );
  }

  /// Daily habits are scheduled every day; specific-day habits on their
  /// weekdays (1 = Monday). Weekly "N times a week" habits have no fixed
  /// day, so they are not counted as scheduled (completions still count).
  bool _isScheduled(Habit h, DateTime day) {
    switch (h.frequency) {
      case HabitFrequency.daily:
        return !day.isBefore(dayOf(h.createdAt));
      case HabitFrequency.specificDays:
        return h.specificDays.contains(day.weekday) &&
            !day.isBefore(dayOf(h.createdAt));
      case HabitFrequency.weekly:
        return false;
    }
  }
}

class _Sources {
  const _Sources({
    required this.completions,
    required this.completedTasks,
    required this.dueDates,
    required this.habitDays,
    required this.doneTitlesByDate,
  });

  final List<TaskCompletionFact> completions;
  final List<CompletedTaskFact> completedTasks;
  final List<DateTime> dueDates;
  final List<HabitDayFact> habitDays;
  final Map<String, List<String>> doneTitlesByDate;

  List<String> habitTitlesDoneOn(DateTime d) {
    final key =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return doneTitlesByDate[key] ?? const [];
  }
}
