import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/habit.dart';
import 'package:omnilife/domain/usecases/habits/habit_streaks.dart';

/// Builds yyyy-MM-dd keys for days relative to [base] (negative = past).
List<String> days(DateTime base, List<int> offsets) => [
  for (final o in offsets)
    HabitStreaks.dateKey(DateTime(base.year, base.month, base.day + o)),
];

StreakResult daily(Iterable<String> logs, DateTime today) =>
    HabitStreaks.compute(
      completedDates: logs,
      frequency: HabitFrequency.daily,
      today: today,
    );

void main() {
  // Wednesday 11 March 2026.
  final today = DateTime(2026, 3, 11, 15, 30);

  group('daily', () {
    test('no logs is zero', () {
      expect(daily([], today), const StreakResult(current: 0, longest: 0));
    });

    test('completed today counts toward current', () {
      expect(
        daily(days(today, [0, -1, -2]), today),
        const StreakResult(current: 3, longest: 3),
      );
    });

    test('today not yet done does not break a streak ending yesterday', () {
      expect(
        daily(days(today, [-1, -2, -3]), today),
        const StreakResult(current: 3, longest: 3),
      );
    });

    test('a missed day before yesterday breaks the current streak', () {
      expect(
        daily(days(today, [-2, -3, -4]), today),
        const StreakResult(current: 0, longest: 3),
      );
    });

    test('gap splits runs; longest keeps the best, current the latest', () {
      final r = daily(days(today, [0, -1, -4, -5, -6, -7, -8]), today);
      expect(r, const StreakResult(current: 2, longest: 5));
    });

    test('longest can decrease when a log is removed (logs are the truth)', () {
      final full = daily(days(today, [-1, -2, -3, -4]), today);
      final trimmed = daily(days(today, [-1, -3, -4]), today);
      expect(full.longest, 4);
      expect(trimmed, const StreakResult(current: 1, longest: 2));
    });

    test('logs dated in the future are ignored', () {
      expect(
        daily(days(today, [1, 2, 3]), today),
        const StreakResult(current: 0, longest: 0),
      );
    });

    test('malformed and duplicate keys are tolerated', () {
      final r = daily([
        'garbage',
        '2026-13-40',
        '2026-03-11',
        '2026-03-11',
      ], today);
      expect(r, const StreakResult(current: 1, longest: 1));
    });

    test('time of day does not matter around midnight', () {
      final logs = days(DateTime(2026, 3, 11), [0, -1]);
      for (final t in [
        DateTime(2026, 3, 11, 0, 0, 1),
        DateTime(2026, 3, 11, 23, 59, 59),
      ]) {
        expect(daily(logs, t).current, 2);
      }
      // One second into the next day, today (12th) is unlogged, but the
      // streak ending on the 11th is still alive.
      expect(daily(logs, DateTime(2026, 3, 12, 0, 0, 1)).current, 2);
      // Two days later it is broken.
      expect(daily(logs, DateTime(2026, 3, 13, 0, 0, 1)).current, 0);
    });

    test('streak spans month, year and leap-day boundaries', () {
      final logs = [
        '2024-02-28',
        '2024-02-29',
        '2024-03-01',
        '2023-12-31',
        '2024-01-01',
      ];
      final r = daily(logs, DateTime(2024, 3, 1));
      expect(r.current, 3);
      expect(r.longest, 3);
      final yearEnd = daily([
        '2025-12-30',
        '2025-12-31',
        '2026-01-01',
      ], DateTime(2026, 1, 1));
      expect(yearEnd.current, 3);
    });

    test('runs correctly across DST changes (no 24h arithmetic)', () {
      // US spring-forward 8 Mar 2026, fall-back 1 Nov 2026; European
      // 29 Mar / 25 Oct. Day-number arithmetic is immune either way.
      for (final start in [
        DateTime(2026, 3, 6),
        DateTime(2026, 3, 27),
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 23),
      ]) {
        final logs = [
          for (var i = 0; i < 6; i++)
            HabitStreaks.dateKey(
              DateTime(start.year, start.month, start.day + i),
            ),
        ];
        final end = DateTime(start.year, start.month, start.day + 5, 0, 30);
        expect(daily(logs, end), const StreakResult(current: 6, longest: 6));
      }
    });
  });

  group('specific days', () {
    // Mon/Wed/Fri habit. 11 Mar 2026 is a Wednesday.
    StreakResult mwf(Iterable<String> logs, DateTime today) =>
        HabitStreaks.compute(
          completedDates: logs,
          frequency: HabitFrequency.specificDays,
          specificDays: const [1, 3, 5],
          today: today,
        );

    test('unscheduled days neither break nor extend', () {
      // Fri 6, Mon 9, Wed 11 done; weekend and Tue skipped.
      final r = mwf(['2026-03-06', '2026-03-09', '2026-03-11'], today);
      expect(r, const StreakResult(current: 3, longest: 3));
    });

    test('a missed scheduled day breaks the streak', () {
      // Missed Mon 9; Fri 6 and Wed 11 done.
      final r = mwf(['2026-03-04', '2026-03-06', '2026-03-11'], today);
      expect(r, const StreakResult(current: 1, longest: 2));
    });

    test('today is scheduled but not yet done: streak stays alive', () {
      final r = mwf(['2026-03-06', '2026-03-09'], today);
      expect(r.current, 2);
    });

    test('yesterday scheduled and missed: streak is broken', () {
      // Thursday 12th is not scheduled, Wed 11th missed.
      final r = mwf(['2026-03-06', '2026-03-09'], DateTime(2026, 3, 12));
      expect(r.current, 0);
      expect(r.longest, 2);
    });

    test('a log on an unscheduled day still counts toward the run', () {
      final r = mwf(['2026-03-09', '2026-03-10', '2026-03-11'], today);
      expect(r.current, 3);
    });

    test('empty specificDays falls back to daily behaviour', () {
      final r = HabitStreaks.compute(
        completedDates: ['2026-03-10', '2026-03-11'],
        frequency: HabitFrequency.specificDays,
        specificDays: const [],
        today: today,
      );
      expect(r.current, 2);
    });
  });

  group('weekly target', () {
    StreakResult weekly(Iterable<String> logs, DateTime today, int target) =>
        HabitStreaks.compute(
          completedDates: logs,
          frequency: HabitFrequency.weekly,
          targetDaysPerWeek: target,
          today: today,
        );

    test('counts consecutive weeks that hit the target', () {
      // Weeks starting Mon 16 Feb, 23 Feb, 2 Mar each with 3 logs.
      final logs = [
        '2026-02-16',
        '2026-02-18',
        '2026-02-20',
        '2026-02-23',
        '2026-02-25',
        '2026-02-27',
        '2026-03-02',
        '2026-03-04',
        '2026-03-06',
      ];
      expect(
        weekly(logs, today, 3),
        const StreakResult(current: 3, longest: 3),
      );
    });

    test('the in-progress week never breaks the streak', () {
      final logs = ['2026-03-02', '2026-03-04', '2026-03-06'];
      // Week of 9 Mar has 1 of 3 so far; previous week counts.
      expect(weekly([...logs, '2026-03-09'], today, 3).current, 1);
    });

    test('a completed current week extends the streak', () {
      final logs = [
        '2026-03-02',
        '2026-03-04',
        '2026-03-06',
        '2026-03-09',
        '2026-03-10',
        '2026-03-11',
      ];
      expect(weekly(logs, today, 3).current, 2);
    });

    test('a past week below target resets current but keeps longest', () {
      final logs = [
        '2026-02-16', '2026-02-18', '2026-02-20', // met
        '2026-02-23', // not met
        '2026-03-02', '2026-03-04', '2026-03-06', // met
      ];
      expect(
        weekly(logs, today, 3),
        const StreakResult(current: 1, longest: 1),
      );
    });

    test('weeks start on Monday (Sunday belongs to the earlier week)', () {
      // Sun 8 Mar + Mon 9 Mar are different weeks.
      final r = weekly(['2026-03-08', '2026-03-09'], today, 2);
      expect(r.longest, 0);
    });

    test('target is clamped to 1..7', () {
      expect(weekly(['2026-03-10'], today, 0).current, 1);
      expect(weekly(['2026-03-10'], today, 99).current, 0);
    });
  });

  test('dayNumber helpers agree with the calendar', () {
    expect(HabitStreaks.weekdayOf(HabitStreaks.dayNumberOf('2026-03-11')!), 3);
    expect(HabitStreaks.weekdayOf(HabitStreaks.dayNumberOf('2026-03-08')!), 7);
    expect(HabitStreaks.weekdayOf(HabitStreaks.dayNumberOf('1970-01-01')!), 4);
    final n = HabitStreaks.dayNumberOf('2026-03-11')!;
    expect(HabitStreaks.dateOfDayNumber(n), DateTime(2026, 3, 11));
    expect(HabitStreaks.dateKey(DateTime(7, 1, 2)), '0007-01-02');
  });
}
