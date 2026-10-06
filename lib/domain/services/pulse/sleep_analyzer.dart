import 'dart:math';

import '../../entities/life_event.dart';

/// One night of user-recorded sleep: a `sleep_start` event paired with the
/// next `wake` event. Derived on read from the events, so correcting either
/// timestamp immediately corrects the duration, consistency and trends.
///
/// This is user-recorded data, not a medical-grade measurement.
class SleepSession {
  const SleepSession({
    required this.startEventId,
    required this.endEventId,
    required this.start,
    required this.end,
  });

  final String startEventId;
  final String endEventId;
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  /// The day the user woke up; sleep is attributed to that day.
  DateTime get wakeDay => DateTime(end.year, end.month, end.day);

  /// Bedtime as minutes since the previous noon, so 23:30 (1410) and 00:30
  /// (1470) are 60 apart instead of wrapping across midnight.
  int get bedtimeMinutesFromNoon {
    final m = start.hour * 60 + start.minute;
    return m < 12 * 60 ? m + 24 * 60 : m;
  }
}

class SleepSummary {
  const SleepSummary({
    required this.nights,
    required this.averageDuration,
    required this.averageBedtime,
    required this.bedtimeStdDevMinutes,
    required this.weeklyAverages,
    required this.trendMinutesPerWeek,
    required this.last30DayAverage,
    required this.previous30DayAverage,
  });

  final int nights;
  final Duration? averageDuration;

  /// Time of day (as minutes after midnight, 0-1439).
  final int? averageBedtime;

  /// Regularity of bedtimes in minutes; lower is more consistent.
  final double? bedtimeStdDevMinutes;

  /// Average duration per calendar week (Monday-start), oldest first.
  final List<WeeklySleepAverage> weeklyAverages;

  /// Least-squares slope of weekly averages, minutes per week. Null with
  /// fewer than three weeks of data.
  final double? trendMinutesPerWeek;
  final Duration? last30DayAverage;
  final Duration? previous30DayAverage;
}

class WeeklySleepAverage {
  const WeeklySleepAverage(this.weekStart, this.average, this.nights);
  final DateTime weekStart;
  final Duration average;
  final int nights;
}

class SleepAnalyzer {
  const SleepAnalyzer({
    this.maxSession = const Duration(hours: 20),
    this.minSession = const Duration(minutes: 20),
  });

  /// Longer gaps are treated as a forgotten wake tap, not one huge sleep.
  final Duration maxSession;

  /// Shorter spans are treated as an accidental pair of taps.
  final Duration minSession;

  /// Pairs each `wake` with the latest unmatched `sleep_start` before it.
  List<SleepSession> sessions(Iterable<LifeEvent> events) {
    final sorted =
        events
            .where(
              (e) =>
                  e.type == LifeEventType.sleepStart ||
                  e.type == LifeEventType.wake,
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final result = <SleepSession>[];
    LifeEvent? open;
    for (final e in sorted) {
      if (e.type == LifeEventType.sleepStart) {
        open = e; // A second start replaces a forgotten earlier one.
      } else if (open != null) {
        final span = e.timestamp.difference(open.timestamp);
        if (span >= minSession && span <= maxSession) {
          result.add(
            SleepSession(
              startEventId: open.id,
              endEventId: e.id,
              start: open.timestamp,
              end: e.timestamp,
            ),
          );
        }
        open = null;
      }
    }
    return result;
  }

  /// The latest `sleep_start` with no `wake` after it, i.e. "sleeping now".
  LifeEvent? openSleep(Iterable<LifeEvent> events, {required DateTime now}) {
    final relevant =
        events
            .where(
              (e) =>
                  (e.type == LifeEventType.sleepStart ||
                      e.type == LifeEventType.wake) &&
                  !e.timestamp.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (relevant.isEmpty) return null;
    final last = relevant.last;
    if (last.type != LifeEventType.sleepStart) return null;
    if (now.difference(last.timestamp) > maxSession) return null;
    return last;
  }

  SleepSummary summarize(List<SleepSession> sessions, {required DateTime now}) {
    if (sessions.isEmpty) {
      return const SleepSummary(
        nights: 0,
        averageDuration: null,
        averageBedtime: null,
        bedtimeStdDevMinutes: null,
        weeklyAverages: [],
        trendMinutesPerWeek: null,
        last30DayAverage: null,
        previous30DayAverage: null,
      );
    }

    final bedtimes = sessions
        .map((s) => s.bedtimeMinutesFromNoon.toDouble())
        .toList();
    final meanBed = bedtimes.reduce((a, b) => a + b) / bedtimes.length;
    final std = bedtimes.length < 2 ? null : _stdDev(bedtimes, meanBed);

    final weekly = _weekly(sessions);
    final today = DateTime(now.year, now.month, now.day);
    final last30 = sessions.where(
      (s) =>
          !s.wakeDay.isBefore(today.subtract(const Duration(days: 29))) &&
          !s.wakeDay.isAfter(today),
    );
    final prev30 = sessions.where(
      (s) =>
          !s.wakeDay.isBefore(today.subtract(const Duration(days: 59))) &&
          s.wakeDay.isBefore(today.subtract(const Duration(days: 29))),
    );

    return SleepSummary(
      nights: sessions.length,
      averageDuration: _avg(sessions),
      averageBedtime: meanBed.round() % (24 * 60),
      bedtimeStdDevMinutes: std,
      weeklyAverages: weekly,
      trendMinutesPerWeek: _slope(weekly),
      last30DayAverage: _avgOrNull(last30.toList()),
      previous30DayAverage: _avgOrNull(prev30.toList()),
    );
  }

  Duration _avg(List<SleepSession> s) => Duration(
    minutes: (s.fold<int>(0, (sum, e) => sum + e.duration.inMinutes) / s.length)
        .round(),
  );

  Duration? _avgOrNull(List<SleepSession> s) => s.isEmpty ? null : _avg(s);

  double _stdDev(List<double> values, double mean) {
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }

  List<WeeklySleepAverage> _weekly(List<SleepSession> sessions) {
    final byWeek = <DateTime, List<SleepSession>>{};
    for (final s in sessions) {
      final day = s.wakeDay;
      final monday = day.subtract(Duration(days: day.weekday - 1));
      byWeek.putIfAbsent(monday, () => []).add(s);
    }
    final keys = byWeek.keys.toList()..sort();
    return [
      for (final k in keys)
        WeeklySleepAverage(k, _avg(byWeek[k]!), byWeek[k]!.length),
    ];
  }

  double? _slope(List<WeeklySleepAverage> weeks) {
    if (weeks.length < 3) return null;
    final n = weeks.length;
    final xs = List<double>.generate(n, (i) => i.toDouble());
    final ys = weeks.map((w) => w.average.inMinutes.toDouble()).toList();
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (xs[i] - mx) * (ys[i] - my);
      den += pow(xs[i] - mx, 2);
    }
    return den == 0 ? null : num / den;
  }
}
