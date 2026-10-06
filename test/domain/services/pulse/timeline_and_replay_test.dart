import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/services/pulse/day_replay.dart';
import 'package:omnilife/domain/services/pulse/daily_facts.dart';
import 'package:omnilife/domain/services/pulse/sleep_analyzer.dart';
import 'package:omnilife/domain/services/pulse/timeline_builder.dart';

import 'pulse_test_helpers.dart';

void main() {
  final day = DateTime(2026, 3, 2);

  group('DailyFactsBuilder', () {
    test('aggregates events, tasks and habits per local day', () {
      final events = [
        ev(LifeEventType.focus, DateTime(2026, 3, 2, 9), meta: {'minutes': 25}),
        ev(
          LifeEventType.focus,
          DateTime(2026, 3, 2, 10),
          meta: {'minutes': 50},
        ),
        ev(LifeEventType.water, DateTime(2026, 3, 2, 11)),
        ev(LifeEventType.water, DateTime(2026, 3, 2, 12), meta: {'ml': 500}),
        ev(LifeEventType.mood, DateTime(2026, 3, 2, 13), meta: {'score': 4}),
        ev(LifeEventType.mood, DateTime(2026, 3, 2, 18), meta: {'score': 2}),
        ev(LifeEventType.energy, DateTime(2026, 3, 2, 15), meta: {'level': 2}),
        ev(
          LifeEventType.workout,
          DateTime(2026, 3, 1, 18),
          meta: {'minutes': 30},
        ),
      ];

      final facts = const DailyFactsBuilder().build(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 3),
        events: events,
        taskCompletions: [
          TaskCompletionFact(DateTime(2026, 3, 2, 10)),
          TaskCompletionFact(DateTime(2026, 3, 2, 16)),
        ],
        taskDueDates: [DateTime(2026, 3, 2), DateTime(2026, 3, 3)],
        habitDays: [
          HabitDayFact(day: DateTime(2026, 3, 2), scheduled: 3, done: 2),
        ],
      );

      expect(facts, hasLength(3)); // includes the empty 3rd day
      final d1 = facts[0], d2 = facts[1], d3 = facts[2];
      expect(d1.workouts, 1);
      expect(d1.workoutMinutes, 30);
      expect(d2.focusSessions, 2);
      expect(d2.focusMinutes, 75);
      expect(d2.waterMl, 750); // 250 default + 500
      expect(d2.averageMood, 3);
      expect(d2.energyEntries.single.hour, 15);
      expect(d2.tasksCompleted, 2);
      expect(d2.tasksDue, 1);
      expect(d2.habitCompletionRate, closeTo(2 / 3, 1e-9));
      expect(d3.hasAction, isFalse);
    });

    test('sleep is attributed to the day the user woke up', () {
      final facts = const DailyFactsBuilder().build(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 2),
        events: [
          ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 23)),
          ev(LifeEventType.wake, DateTime(2026, 3, 2, 7)),
        ],
      );

      expect(facts[0].sleepMinutes, isNull);
      expect(facts[1].sleepMinutes, 480);
    });

    test('task_completed events are not double counted with real tasks', () {
      final facts = const DailyFactsBuilder().build(
        from: day,
        to: day,
        events: [ev(LifeEventType.taskCompleted, DateTime(2026, 3, 2, 9))],
        taskCompletions: [TaskCompletionFact(DateTime(2026, 3, 2, 9))],
      );
      expect(facts.single.tasksCompleted, 1);
    });
  });

  group('TimelineBuilder', () {
    final wakeEvent = ev(LifeEventType.wake, DateTime(2026, 3, 2, 7, 18));
    final events = [
      ev(LifeEventType.sleepStart, DateTime(2026, 3, 1, 23, 42)),
      wakeEvent,
      ev(
        LifeEventType.meal,
        DateTime(2026, 3, 2, 8, 5),
        meta: {'kind': 'breakfast'},
      ),
      ev(LifeEventType.water, DateTime(2026, 3, 2, 8, 30)),
      ev(LifeEventType.water, DateTime(2026, 3, 2, 8, 50)),
      ev(
        LifeEventType.focus,
        DateTime(2026, 3, 2, 9, 12),
        meta: {'minutes': 25},
      ),
      ev(
        LifeEventType.energy,
        DateTime(2026, 3, 2, 14, 30),
        meta: {'level': 2},
      ),
    ];

    test('orders everything chronologically and merges other modules', () {
      final entries = const TimelineBuilder().forDay(
        day,
        events: events,
        completedTasks: [
          CompletedTaskFact('Write report', DateTime(2026, 3, 2, 10, 3)),
        ],
        habitsDone: const ['Read 20 min'],
      );

      final titles = entries.map((e) => e.title).toList();
      expect(titles, [
        'Wake',
        'Breakfast',
        'Water x2',
        'Focus',
        'Task completed',
        'Energy: Low',
        'Habit', // untimed entries sort last
      ]);
      expect(entries.last.time, isNull);
    });

    test(
      'wake shows the slept duration; the sleep start is on its own day',
      () {
        final entries = const TimelineBuilder().forDay(day, events: events);
        final wake = entries.firstWhere((e) => e.kind == TimelineKind.wake);
        expect(wake.detail, 'Slept 7h 36m');
        expect(wake.eventId, wakeEvent.id);

        final previous = const TimelineBuilder().forDay(
          DateTime(2026, 3, 1),
          events: events,
        );
        expect(previous.single.kind, TimelineKind.sleep);
      },
    );

    test('same-hour water taps merge into one total', () {
      final water = const TimelineBuilder()
          .forDay(day, events: events)
          .firstWhere((e) => e.kind == TimelineKind.water);
      expect(water.detail, '500 ml');
      expect(water.isEditable, isFalse); // merged group has no single event
    });
  });

  group('DayReplayBuilder', () {
    DayReplay build(DailyFacts facts, List<SleepSession> sessions) =>
        const DayReplayBuilder().build(day, facts: facts, sessions: sessions);

    test('an empty day says so plainly', () {
      final r = build(DailyFacts(day), const []);
      expect(r.isEmpty, isTrue);
      expect(r.summary, 'Nothing was logged for this day.');
    });

    test('three focus sessions is described as a focused day, with counts', () {
      final f = DailyFacts(day)
        ..focusSessions = 3
        ..focusMinutes = 95
        ..tasksCompleted = 7;
      final session = SleepSession(
        startEventId: 'a',
        endEventId: 'b',
        start: DateTime(2026, 3, 1, 23, 42),
        end: DateTime(2026, 3, 2, 7, 18),
      );

      final r = build(f, [session]);

      expect(r.summary, startsWith('You had a focused day'));
      expect(r.summary, contains('7 tasks completed'));
      expect(r.summary, contains('3 focus sessions'));
      expect(r.summary, contains('slept 7h 36m'));
      expect(r.wakeTime, DateTime(2026, 3, 2, 7, 18));
      expect(r.sleepDuration, const Duration(hours: 7, minutes: 36));
    });

    test('the summary uses only recorded counts (no invented claims)', () {
      final f = DailyFacts(day)..tasksCompleted = 1;
      final r = build(f, const []);
      expect(r.summary, 'Here is what you recorded: 1 task completed.');
    });
  });
}
