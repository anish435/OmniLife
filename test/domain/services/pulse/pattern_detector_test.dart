import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/services/pulse/daily_facts.dart';
import 'package:omnilife/domain/services/pulse/pattern_detector.dart';

import 'pulse_test_helpers.dart';

/// 12 days: alternating well-slept / short-slept days with clearly different
/// task counts, plus a little deterministic noise.
List<DailyFacts> _sleepDays({required bool linked}) {
  final days = daysEndingOn(DateTime(2026, 3, 29), 12);
  for (var i = 0; i < days.length; i++) {
    final rested = i.isEven;
    days[i].sleepMinutes = rested ? 460 : 340;
    days[i].tasksCompleted = linked
        ? (rested ? 6 : 3) + (i % 3 == 0 ? 1 : 0)
        : 4 + (i % 3); // same distribution regardless of sleep
  }
  return days;
}

void main() {
  const detector = PatternDetector();

  test('surfaces a sleep/tasks association with its evidence', () {
    final patterns = detector.detect(_sleepDays(linked: true));

    final p = patterns.firstWhere((p) => p.id == 'sleep_tasks');
    expect(
      p.statement,
      startsWith('On days when you logged 7+ hours of sleep'),
    );
    expect(p.statement, contains('you completed more tasks'));
    expect(p.evidenceLine, contains('Based on 12 days (6 vs 6)'));
    expect(p.evidenceLine, contains('not proof of cause'));
    expect(p.evidence!.meanA, greaterThan(p.evidence!.meanB));
  });

  test('does not claim a pattern when the groups do not differ', () {
    final patterns = detector.detect(_sleepDays(linked: false));
    expect(patterns.where((p) => p.id == 'sleep_tasks'), isEmpty);
  });

  test('never speaks from too little data', () {
    final days = _sleepDays(linked: true).sublist(0, 6); // only 6 days
    expect(detector.detect(days), isEmpty);
  });

  test('requires enough days in each group, not just in total', () {
    final days = daysEndingOn(DateTime(2026, 3, 29), 12);
    for (var i = 0; i < days.length; i++) {
      // Only 2 short-sleep days: below the 3-day group minimum.
      days[i].sleepMinutes = i < 2 ? 330 : 470;
      days[i].tasksCompleted = i < 2 ? 0 : 7;
    }
    expect(detector.detect(days).where((p) => p.id == 'sleep_tasks'), isEmpty);
  });

  test('wording never asserts causation or medical effects', () {
    final all = detector
        .detect(_sleepDays(linked: true))
        .map((p) => '${p.statement} ${p.evidenceLine}'.toLowerCase())
        .join(' ');
    expect(all, isNot(contains('because')));
    expect(all, isNot(contains('causes')));
    expect(all, isNot(contains('leads to')));
  });

  test('flags the time of day when low energy is recorded most often', () {
    final days = daysEndingOn(DateTime(2026, 3, 29), 10);
    for (var i = 0; i < days.length; i++) {
      days[i].energyEntries.add(const EnergyEntry(10, 4));
      if (i < 8) days[i].energyEntries.add(const EnergyEntry(14, 2));
    }

    final p = detector
        .detect(days)
        .firstWhere((p) => p.id == 'low_energy_window');

    expect(p.statement, contains('On 8 of 10 days with energy entries'));
    expect(p.statement, contains('between 2 PM and 4 PM'));
  });

  test('orders stronger patterns first', () {
    final days = _sleepDays(linked: true);
    for (var i = 0; i < days.length; i++) {
      days[i].focusMinutes = i.isEven ? 60 : 5;
    }
    final patterns = detector.detect(days);
    for (var i = 1; i < patterns.length; i++) {
      expect(
        patterns[i - 1].strength,
        greaterThanOrEqualTo(patterns[i].strength),
      );
    }
  });
}
