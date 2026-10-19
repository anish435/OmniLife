import '../services/pulse/daily_facts.dart';
import 'logged_fact.dart';

/// What today looks like so far (all sources, after the new logs).
class TodayTotals {
  const TodayTotals({
    this.sleepMinutes,
    this.waterMl = 0,
    this.meals = 0,
    this.workoutMinutes = 0,
    this.focusMinutes = 0,
    this.averageMood,
    this.averageEnergy,
  });

  final int? sleepMinutes;
  final int waterMl;
  final int meals;
  final int workoutMinutes;
  final int focusMinutes;
  final double? averageMood;
  final double? averageEnergy;
}

/// The days before today, in aggregate. Only days that actually have data
/// count, so an unlogged day never drags an average down.
class WeekTotals {
  const WeekTotals({
    this.sleepDays = 0,
    this.averageSleepMinutes,
    this.waterDays = 0,
    this.averageWaterMl,
  });

  final int sleepDays;
  final int? averageSleepMinutes;
  final int waterDays;
  final int? averageWaterMl;

  static const empty = WeekTotals();
}

/// Everything the advice is allowed to look at: what the user just logged,
/// today so far, and the previous days from Pulse. Aggregates only.
class AdviceContext {
  const AdviceContext({
    required this.now,
    required this.logged,
    required this.today,
    required this.week,
  });

  final DateTime now;
  final List<LoggedFact> logged;
  final TodayTotals today;
  final WeekTotals week;

  /// Builds the context from Pulse daily facts. The fact for [now]'s day is
  /// "today"; up to the six days before it make the week.
  factory AdviceContext.fromFacts({
    required DateTime now,
    required List<LoggedFact> logged,
    required List<DailyFacts> days,
  }) {
    final todayKey = dayOf(now);
    DailyFacts? todayFacts;
    final prior = <DailyFacts>[];
    for (final d in days) {
      final k = dayOf(d.day);
      if (k == todayKey) {
        todayFacts = d;
      } else if (k.isBefore(todayKey) &&
          !k.isBefore(todayKey.subtract(const Duration(days: 6)))) {
        prior.add(d);
      }
    }

    final sleep = prior
        .map((d) => d.sleepMinutes)
        .whereType<int>()
        .where((m) => m > 0)
        .toList();
    final water = prior.map((d) => d.waterMl).where((m) => m > 0).toList();
    int? avg(List<int> v) =>
        v.isEmpty ? null : (v.reduce((a, b) => a + b) / v.length).round();

    return AdviceContext(
      now: now,
      logged: logged,
      today: todayFacts == null
          ? const TodayTotals()
          : TodayTotals(
              sleepMinutes: todayFacts.sleepMinutes,
              waterMl: todayFacts.waterMl,
              meals: todayFacts.meals,
              workoutMinutes: todayFacts.workoutMinutes,
              focusMinutes: todayFacts.focusMinutes,
              averageMood: todayFacts.averageMood,
              averageEnergy: todayFacts.averageEnergy,
            ),
      week: WeekTotals(
        sleepDays: sleep.length,
        averageSleepMinutes: avg(sleep),
        waterDays: water.length,
        averageWaterMl: avg(water),
      ),
    );
  }

  /// The most recent logged value of [kind] from this message, if any.
  int? latest(LoggedKind kind) {
    for (final f in logged.reversed) {
      if (f.kind == kind && f.value != null) return f.value;
    }
    return null;
  }

  bool has(LoggedKind kind) => logged.any((f) => f.kind == kind);

  /// A compact, stable text summary (about 100 tokens). Used as the model
  /// context and, hashed, as the cache key. No titles, no free text.
  String summary() {
    final b = StringBuffer();
    String two(int n) => n.toString().padLeft(2, '0');
    b.writeln(
      'Now: ${now.year}-${two(now.month)}-${two(now.day)} '
      '${two(now.hour)}:00',
    );
    final told = [
      for (final f in logged)
        switch (f.kind) {
          LoggedKind.sleep => 'slept ${formatMinutes(f.value ?? 0)}',
          LoggedKind.water => 'water ${f.value ?? 0} ml',
          LoggedKind.meal => 'ate a meal',
          LoggedKind.workout => 'workout ${f.value ?? 0} min',
          LoggedKind.mood => 'mood ${f.value}/5',
          LoggedKind.energy => 'energy ${f.value}/5',
          LoggedKind.focus => 'focus ${f.value ?? 0} min',
        },
    ];
    b.writeln('Just told: ${told.join(', ')}');
    final t = today;
    b.writeln(
      'Today so far: water ${t.waterMl} ml, meals ${t.meals}, '
      'workout ${t.workoutMinutes} min, focus ${t.focusMinutes} min'
      '${t.sleepMinutes == null ? '' : ', sleep ${formatMinutes(t.sleepMinutes!)}'}',
    );
    final w = week;
    b.writeln(
      'Previous days: '
      '${w.averageSleepMinutes == null ? 'no sleep data' : 'sleep avg ${formatMinutes(w.averageSleepMinutes!)} over ${w.sleepDays} nights'}'
      ', '
      '${w.averageWaterMl == null ? 'no water data' : 'water avg ${w.averageWaterMl} ml over ${w.waterDays} days'}',
    );
    return b.toString().trim();
  }
}

/// 200 -> "3h 20m", 180 -> "3h", 45 -> "45m".
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
