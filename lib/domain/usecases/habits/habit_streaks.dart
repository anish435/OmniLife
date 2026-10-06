import '../../entities/habit.dart';

class StreakResult {
  const StreakResult({required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  bool operator ==(Object other) =>
      other is StreakResult &&
      other.current == current &&
      other.longest == longest;

  @override
  int get hashCode => Object.hash(current, longest);

  @override
  String toString() => 'StreakResult(current: $current, longest: $longest)';
}

/// Streak maths for habits, in pure Dart and independent of the device
/// time zone.
///
/// Log dates are local calendar days stored as `yyyy-MM-dd`. They are turned
/// into integer "day numbers" (days since the Unix epoch, computed in UTC) so
/// stepping a day never depends on 24-hour arithmetic that DST can break.
///
/// Rules:
/// * Daily: a streak is consecutive completed days.
/// * Specific days: only scheduled weekdays can break a streak; an unscheduled
///   day with no log is skipped, a log on an unscheduled day still counts.
/// * Weekly (targetDaysPerWeek): the unit is a Monday-start week that reached
///   its target. Consecutive successful weeks make a streak.
/// * Today (or the current week) still in progress never breaks the streak;
///   it only adds to it once completed.
/// * Logs dated after today are ignored.
abstract final class HabitStreaks {
  static const _msPerDay = 86400000;

  /// `yyyy-MM-dd` for the local calendar day of [date].
  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Day number for a `yyyy-MM-dd` string, or null if malformed.
  static int? dayNumberOf(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, mo, d).millisecondsSinceEpoch ~/ _msPerDay;
  }

  /// Day number of the local calendar day of [date] (time of day ignored).
  static int dayNumberOfDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      _msPerDay;

  /// Local calendar date (midnight, local) for a day number.
  static DateTime dateOfDayNumber(int day) {
    final u = DateTime.fromMillisecondsSinceEpoch(day * _msPerDay, isUtc: true);
    return DateTime(u.year, u.month, u.day);
  }

  /// ISO weekday (Mon=1..Sun=7) of a day number.
  static int weekdayOf(int day) => ((day + 3) % 7) + 1;

  static int _floorDiv(int a, int b) => (a / b).floor();

  /// Index of the Monday-start week containing [day].
  static int weekIndexOf(int day) => _floorDiv(day - 4, 7);

  static StreakResult compute({
    required Iterable<String> completedDates,
    required HabitFrequency frequency,
    List<int> specificDays = const [],
    int targetDaysPerWeek = 7,
    required DateTime today,
  }) {
    final todayNo = dayNumberOfDate(today);
    final days = <int>{};
    for (final key in completedDates) {
      final n = dayNumberOf(key);
      if (n != null && n <= todayNo) days.add(n);
    }
    if (days.isEmpty) return const StreakResult(current: 0, longest: 0);

    switch (frequency) {
      case HabitFrequency.weekly:
        return _weekly(days, todayNo, targetDaysPerWeek);
      case HabitFrequency.specificDays:
        final scheduled = specificDays.where((d) => d >= 1 && d <= 7).toSet();
        if (scheduled.isNotEmpty) {
          return _daily(days, todayNo, scheduled: scheduled);
        }
        return _daily(days, todayNo);
      case HabitFrequency.daily:
        return _daily(days, todayNo);
    }
  }

  static StreakResult _daily(
    Set<int> days,
    int todayNo, {
    Set<int>? scheduled,
  }) {
    var first = todayNo;
    for (final d in days) {
      if (d < first) first = d;
    }
    var run = 0;
    var longest = 0;
    for (var d = first; d <= todayNo; d++) {
      if (days.contains(d)) {
        run++;
        if (run > longest) longest = run;
      } else {
        final isMiss =
            d != todayNo &&
            (scheduled == null || scheduled.contains(weekdayOf(d)));
        if (isMiss) run = 0;
      }
    }
    return StreakResult(current: run, longest: longest);
  }

  static StreakResult _weekly(Set<int> days, int todayNo, int target) {
    final need = target.clamp(1, 7);
    final perWeek = <int, int>{};
    for (final d in days) {
      final w = weekIndexOf(d);
      perWeek[w] = (perWeek[w] ?? 0) + 1;
    }
    final firstWeek = perWeek.keys.reduce((a, b) => a < b ? a : b);
    final thisWeek = weekIndexOf(todayNo);
    var run = 0;
    var longest = 0;
    for (var w = firstWeek; w <= thisWeek; w++) {
      final met = (perWeek[w] ?? 0) >= need;
      if (met) {
        run++;
        if (run > longest) longest = run;
      } else if (w != thisWeek) {
        run = 0;
      }
    }
    return StreakResult(current: run, longest: longest);
  }
}
