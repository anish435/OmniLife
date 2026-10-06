import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/services/pulse/sleep_analyzer.dart';

import 'pulse_test_helpers.dart';

void main() {
  const analyzer = SleepAnalyzer();

  test('pairs a wake with the preceding sleep start and computes duration', () {
    final events = [
      ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 23, 42)),
      ev(LifeEventType.wake, DateTime(2026, 3, 2, 7, 18)),
    ];

    final sessions = analyzer.sessions(events);

    expect(sessions, hasLength(1));
    expect(sessions.single.duration, const Duration(hours: 7, minutes: 36));
    expect(sessions.single.wakeDay, DateTime(2026, 3, 2));
  });

  test('ignores a wake with no sleep start and implausible spans', () {
    final events = [
      ev(LifeEventType.wake, DateTime(2026, 3, 1, 7)),
      // 25h gap: a forgotten wake tap, not one giant sleep.
      ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 22)),
      ev(LifeEventType.wake, DateTime(2026, 3, 2, 23)),
      // 5 minute pair: accidental taps.
      ev(LifeEventType.sleepStart, DateTime(2026, 3, 3, 22)),
      ev(LifeEventType.wake, DateTime(2026, 3, 3, 22, 5)),
    ];

    expect(analyzer.sessions(events), isEmpty);
  });

  test('a second sleep start replaces a forgotten earlier one', () {
    final events = [
      ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 21)),
      ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 23)),
      ev(LifeEventType.wake, DateTime(2026, 3, 2, 7)),
    ];

    final s = analyzer.sessions(events).single;

    expect(s.start, DateTime(2026, 3, 1, 23));
    expect(s.duration, const Duration(hours: 8));
  });

  test('editing an event timestamp changes the derived duration', () {
    final start = ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 23));
    final wake = ev(LifeEventType.wake, DateTime(2026, 3, 2, 7));
    final corrected = start.copyWith(timestamp: DateTime(2026, 3, 1, 22, 30));

    expect(
      analyzer.sessions([start, wake]).single.duration,
      const Duration(hours: 8),
    );
    expect(
      analyzer.sessions([corrected, wake]).single.duration,
      const Duration(hours: 8, minutes: 30),
    );
  });

  test('openSleep reports sleeping now, and null once woken', () {
    final start = ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 23, 42));
    final now = DateTime(2026, 3, 2, 2);

    expect(analyzer.openSleep([start], now: now)?.id, start.id);

    final wake = ev(LifeEventType.wake, DateTime(2026, 3, 2, 1));
    expect(analyzer.openSleep([start, wake], now: now), isNull);

    // Over 20h ago: treated as stale, not "sleeping now".
    expect(analyzer.openSleep([start], now: DateTime(2026, 3, 3, 23)), isNull);
  });

  group('summary', () {
    List<SleepSession> nights(List<(DateTime, DateTime)> pairs) =>
        analyzer.sessions([
          for (final p in pairs) ...[
            ev(LifeEventType.sleepStart, p.$1),
            ev(LifeEventType.wake, p.$2),
          ],
        ]);

    test('bedtime across midnight averages correctly', () {
      final s = analyzer.summarize(
        nights([
          (DateTime(2026, 3, 1, 23, 30), DateTime(2026, 3, 2, 7)),
          (DateTime(2026, 3, 3, 0, 30), DateTime(2026, 3, 3, 8)),
        ]),
        now: DateTime(2026, 3, 4),
      );

      // 23:30 and 00:30 average to exactly midnight, not noon.
      expect(s.averageBedtime, 0);
      expect(s.bedtimeStdDevMinutes, closeTo(30, 0.001));
      expect(s.averageDuration, const Duration(hours: 7, minutes: 30));
    });

    test('weekly averages and a falling trend are computed', () {
      final pairs = <(DateTime, DateTime)>[];
      // Four Mondays: 8h, 7h, 6h, 5h of sleep.
      for (var w = 0; w < 4; w++) {
        final mon = DateTime(2026, 3, 2).add(Duration(days: 7 * w));
        pairs.add((
          mon.subtract(Duration(hours: 24 - 23)),
          mon.subtract(Duration(hours: 24 - 23)).add(Duration(hours: 8 - w)),
        ));
      }
      final s = analyzer.summarize(nights(pairs), now: DateTime(2026, 4, 1));

      expect(s.weeklyAverages, hasLength(4));
      expect(s.trendMinutesPerWeek, closeTo(-60, 0.001));
    });

    test('an empty history yields an empty summary', () {
      final s = analyzer.summarize(const [], now: DateTime(2026, 3, 1));
      expect(s.nights, 0);
      expect(s.averageDuration, isNull);
      expect(s.trendMinutesPerWeek, isNull);
    });
  });
}
