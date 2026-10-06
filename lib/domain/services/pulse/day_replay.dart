import 'daily_facts.dart';
import 'sleep_analyzer.dart';
import 'timeline_builder.dart';

/// A factual one-screen summary of a single day, built only from what the
/// user recorded. The summary sentence is rule-based over counts and makes
/// no psychological or medical claims.
class DayReplay {
  const DayReplay({
    required this.day,
    required this.wakeTime,
    required this.sleepDuration,
    required this.focusSessions,
    required this.focusMinutes,
    required this.tasksCompleted,
    required this.workouts,
    required this.habitsDone,
    required this.meals,
    required this.waterMl,
    required this.averageMood,
    required this.summary,
    required this.isEmpty,
  });

  final DateTime day;
  final DateTime? wakeTime;

  /// The sleep that ended on this day.
  final Duration? sleepDuration;
  final int focusSessions;
  final int focusMinutes;
  final int tasksCompleted;
  final int workouts;
  final int habitsDone;
  final int meals;
  final int waterMl;
  final double? averageMood;
  final String summary;
  final bool isEmpty;
}

class DayReplayBuilder {
  const DayReplayBuilder({this.sleepAnalyzer = const SleepAnalyzer()});

  final SleepAnalyzer sleepAnalyzer;

  DayReplay build(
    DateTime day, {
    required DailyFacts facts,
    required List<SleepSession> sessions,
  }) {
    final d = dayOf(day);
    final night = sessions.where((s) => s.wakeDay == d).toList()
      ..sort((a, b) => a.end.compareTo(b.end));
    final wake = night.isEmpty ? null : night.last.end;
    final sleep = night.isEmpty
        ? null
        : Duration(
            minutes: night.fold<int>(0, (s, e) => s + e.duration.inMinutes),
          );

    final empty = !facts.hasAction;
    return DayReplay(
      day: d,
      wakeTime: wake,
      sleepDuration: sleep,
      focusSessions: facts.focusSessions,
      focusMinutes: facts.focusMinutes,
      tasksCompleted: facts.tasksCompleted,
      workouts: facts.workouts,
      habitsDone: facts.habitsDone,
      meals: facts.meals,
      waterMl: facts.waterMl,
      averageMood: facts.averageMood,
      summary: _summary(facts, sleep),
      isEmpty: empty,
    );
  }

  String _summary(DailyFacts f, Duration? sleep) {
    if (!f.hasAction) return 'Nothing was logged for this day.';
    final parts = <String>[
      if (f.tasksCompleted > 0)
        '${f.tasksCompleted} task${f.tasksCompleted == 1 ? '' : 's'} completed',
      if (f.focusSessions > 0)
        '${f.focusSessions} focus session${f.focusSessions == 1 ? '' : 's'}',
      if (f.workouts > 0) '${f.workouts} workout${f.workouts == 1 ? '' : 's'}',
      if (f.habitsDone > 0)
        '${f.habitsDone} habit${f.habitsDone == 1 ? '' : 's'} done',
      if (sleep != null) 'slept ${formatDuration(sleep)}',
    ];
    final String headline;
    if (f.focusSessions >= 3) {
      headline = 'You had a focused day';
    } else if (f.tasksCompleted >= 5) {
      headline = 'You got a lot done';
    } else if (f.workouts > 0 &&
        f.tasksCompleted == 0 &&
        f.focusSessions == 0) {
      headline = 'A movement day';
    } else {
      headline = 'Here is what you recorded';
    }
    return parts.isEmpty ? '$headline.' : '$headline: ${parts.join(', ')}.';
  }
}
