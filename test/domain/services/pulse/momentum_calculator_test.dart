import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/services/pulse/momentum_calculator.dart';

import 'pulse_test_helpers.dart';

void main() {
  const calc = MomentumCalculator();
  final today = DateTime(2026, 3, 29);

  test('focus is the average minutes per day against the target', () {
    final days = daysEndingOn(today, 28);
    // Last 7 days: 30 focus minutes every day -> 30/60 = 50.
    for (final d in days.sublist(21)) {
      d.focusSessions = 1;
      d.focusMinutes = 30;
    }

    final focus = calc.compute(days).focus;

    expect(focus.score, 50);
    expect(
      focus.components.firstWhere((c) => c.name == 'Average focus').value,
      30,
    );
  });

  test('metrics refuse to score without data, and say what is missing', () {
    final report = calc.compute(daysEndingOn(today, 28));

    for (final m in report.all) {
      expect(m.score, isNull, reason: m.label);
      expect(m.missingReason, isNotNull, reason: m.label);
    }
  });

  test('recovery needs 3 nights and then blends duration and regularity', () {
    final days = daysEndingOn(today, 28);
    for (final d in days.sublist(22, 24)) {
      d.sleepMinutes = 450;
      d.bedtimeMinutesFromNoon = 23 * 60;
    }
    expect(calc.compute(days).recovery.score, isNull);
    expect(calc.compute(days).recovery.missingReason, contains('2 of 3'));

    for (final d in days.sublist(22, 28)) {
      d.sleepMinutes = 450; // exactly the 7.5h target
      d.bedtimeMinutesFromNoon = 23 * 60; // identical bedtime
    }
    expect(calc.compute(days).recovery.score, 100);

    // Short sleep lowers the duration part: 6h = 80% of 7.5h.
    for (final d in days.sublist(22, 28)) {
      d.sleepMinutes = 360;
    }
    // 0.7 * 80 + 0.3 * 100 = 86
    expect(calc.compute(days).recovery.score, 86);
  });

  test('momentum is the recency-weighted share of active days', () {
    final days = daysEndingOn(today, 28);
    for (final d in days.sublist(14)) {
      d.tasksCompleted = 1; // every one of the last 14 days is active
    }
    final all = calc.compute(days).momentum;
    expect(all.score, 100);
    expect(all.components.firstWhere((c) => c.name == 'Current run').value, 14);

    // Only the oldest half active: weighted below 50% because recent days
    // count more.
    for (final d in days.sublist(21)) {
      d.tasksCompleted = 0;
    }
    final half = calc.compute(days).momentum;
    expect(half.score, lessThan(50));
    expect(half.score, greaterThan(0));
  });

  test('balance is 100 for an even spread and lower when lopsided', () {
    final days = daysEndingOn(today, 28);
    final last = days.sublist(21);
    last[0].tasksCompleted = 2; // work 2
    last[1].workouts = 2; // health 2
    last[2].habitsDone = 2; // mind 2
    expect(calc.compute(days).balance.score, 100);

    last[0].tasksCompleted = 20; // now heavily work
    final lopsided = calc.compute(days).balance.score!;
    expect(lopsided, lessThan(70));
  });

  test('balance needs at least 6 recorded actions', () {
    final days = daysEndingOn(today, 28);
    days.last.tasksCompleted = 3;
    final b = calc.compute(days).balance;
    expect(b.score, isNull);
    expect(b.missingReason, contains('3 so far'));
  });

  test('why-changed names the component that moved versus the last window', () {
    final days = daysEndingOn(today, 28);
    for (final d in days.sublist(14, 21)) {
      d.focusSessions = 1;
      d.focusMinutes = 20; // previous week
    }
    for (final d in days.sublist(21)) {
      d.focusSessions = 1;
      d.focusMinutes = 40; // this week
    }

    final focus = calc.compute(days).focus;

    expect(focus.previousScore, 33);
    expect(focus.score, 67);
    expect(focus.delta, 34);
    expect(
      focus.whyChanged.first,
      contains('Average focus rose from 20 to 40'),
    );
  });

  test('the report is deterministic for identical input', () {
    final a = daysEndingOn(today, 28)..last.focusMinutes = 25;
    final b = daysEndingOn(today, 28)..last.focusMinutes = 25;
    a.last.focusSessions = 1;
    b.last.focusSessions = 1;
    expect(calc.compute(a).focus.score, calc.compute(b).focus.score);
  });
}
