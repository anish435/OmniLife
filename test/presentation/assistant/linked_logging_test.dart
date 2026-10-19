import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/assistant/assistant_engine.dart';
import 'package:omnilife/domain/assistant/assistant_tool.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/insights/linked_advisor.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_insights_service.dart';
import 'package:omnilife/presentation/assistant/assistant_tools.dart';

import '../../support/assistant_fakes.dart';

void main() {
  tearDown(Get.reset);

  /// The harness engine plus a real advisor reading the harness's Pulse data.
  Future<(AssistantHarness, AssistantEngine)> setup(
    AiResponse Function(String) script, {
    DateTime? now,
  }) async {
    final h = await AssistantHarness.create(script: script, now: now);
    final insights = PulseInsightsService(
      events: h.lifeEvents,
      tasks: h.taskRepo,
      habits: h.habitRepo,
      now: () => h.now,
    );
    final advisor = DefaultLinkedAdvisor(
      loadDays: () async => (await insights.load('u1', days: 7)).days,
      // The same (scripted) provider: advice must not need a second call
      // when the rules have the answer and the provider returns nothing.
      provider: () => h.provider,
    );
    final engine = AssistantEngine(
      provider: h.provider,
      tools: ToolRegistry(buildAssistantTools(h.deps)),
      now: () => h.now,
      advisor: () => advisor,
    );
    return (h, engine);
  }

  Map<String, dynamic> sleep(num hours) => {'kind': 'sleep', 'hours': hours};

  test(
    'sleep 3h and water 2 L in one message logs both and links them',
    () async {
      final (h, engine) = await setup((text) {
        // The model's single reply carries both tool calls.
        if (text.contains('2 litres')) {
          return calls([
            call('logPulse', sleep(3)),
            AiToolCall(
              id: 'c2',
              name: 'logPulse',
              arguments: {'kind': 'water', 'ml': 2000, 'period': 'morning'},
            ),
          ]);
        }
        return const AiResponse(); // any extra advice call returns nothing
      });

      final turn = await engine.handle(
        'I drank 2 litres of water this morning and slept only 3 hours',
      );

      // Exactly one model call for tool execution, plus at most one more.
      expect(h.provider.requests.length, lessThanOrEqualTo(2));

      final byType = {for (final e in h.lifeEvents.events.values) e.type: e};
      final start = h.lifeEvents.events.values.firstWhere(
        (e) => e.type == LifeEventType.sleepStart,
      );
      final wake = h.lifeEvents.events.values.firstWhere(
        (e) => e.type == LifeEventType.wake,
      );
      expect(wake.timestamp, DateTime(2026, 10, 19, 7));
      expect(start.timestamp, DateTime(2026, 10, 19, 4));
      expect(wake.metadata['durationMinutes'], 180);
      final water = byType[LifeEventType.water]!;
      expect(water.metadata['ml'], 2000);
      expect(water.timestamp, DateTime(2026, 10, 19, 8));

      expect(turn.outcomes.where((o) => o.isWrite), hasLength(2));
      expect(turn.reply, startsWith('Done.'));
      // One piece of advice that uses the user's own numbers.
      expect(turn.reply, contains('Water\'s good at 2 L'));
      expect(turn.reply, contains('only 3h of sleep'));
      expect(turn.reply, contains('Want a reminder at 10 PM?'));

      // Undo on the sleep card removes both of its events.
      final sleepOutcome = turn.outcomes.first;
      await sleepOutcome.undo!();
      expect(h.lifeEvents.events.values.map((e) => e.type), [
        LifeEventType.water,
      ]);
    },
  );

  test(
    'nothing noteworthy: events are logged and no advice is added',
    () async {
      final (h, engine) = await setup(
        (_) => calls([
          call('logPulse', sleep(8)),
          call('logPulse', {'kind': 'water', 'liters': 2, 'period': 'morning'}),
        ]),
      );
      final turn = await engine.handle('slept 8 hours, drank 2 litres');
      expect(h.lifeEvents.events, hasLength(3));
      expect(
        turn.reply,
        'Done. I\'ve logged 8h of sleep. I\'ve logged some water.',
      );
      expect(h.provider.requests, hasLength(1));
    },
  );

  test('workout and focus minutes, mood and energy are recorded', () async {
    final (h, engine) = await setup(
      (_) => calls([
        call('logPulse', {'kind': 'workout', 'minutes': 45, 'text': 'run'}),
        call('logPulse', {'kind': 'focus', 'minutes': 90}),
        call('logPulse', {'kind': 'mood', 'value': 4}),
        call('logPulse', {'kind': 'energy', 'value': 3}),
        call('logPulse', {'kind': 'meal', 'text': 'oats', 'period': 'morning'}),
      ]),
    );
    final turn = await engine.handle('lots of things');
    final events = h.lifeEvents.events.values.toList();
    expect(turn.outcomes.where((o) => o.isWrite), hasLength(5));
    expect(
      events.firstWhere((e) => e.type == LifeEventType.workout).metadata,
      containsPair('minutes', 45),
    );
    expect(
      events.firstWhere((e) => e.type == LifeEventType.focus).metadata,
      containsPair('minutes', 90),
    );
    final meal = events.firstWhere((e) => e.type == LifeEventType.meal);
    expect(meal.timestamp, DateTime(2026, 10, 19, 8));
    expect(meal.metadata['kind'], 'breakfast');
  });

  test(
    'validation: absurd or future values are rejected, not logged',
    () async {
      final (h, engine) = await setup(
        (_) => calls([
          call('logPulse', sleep(40)),
          call('logPulse', {'kind': 'water', 'ml': 90000}),
          call('logPulse', {'kind': 'workout', 'minutes': 0}),
          call('logPulse', {
            'kind': 'water',
            'ml': 300,
            'at': '2026-10-19T23:00',
          }),
          call('logPulse', {'kind': 'focus'}),
        ]),
      );
      final turn = await engine.handle('nonsense');
      expect(h.lifeEvents.events, isEmpty);
      expect(turn.outcomes.map((o) => o.status), [
        ToolStatus.failed,
        ToolStatus.failed,
        ToolStatus.failed,
        ToolStatus.failed,
        ToolStatus.question,
      ]);
      expect(turn.reply, isNot(contains('Water\'s good')));
    },
  );

  test('a stated wake time is used for the sleep session', () async {
    final (h, engine) = await setup(
      (_) => calls([
        call('logPulse', {
          'kind': 'sleep',
          'hours': 5.5,
          'at': '2026-10-19T06:30',
        }),
      ]),
    );
    await engine.handle('slept 5.5 hours, up at 6:30');
    final wake = h.lifeEvents.events.values.firstWhere(
      (e) => e.type == LifeEventType.wake,
    );
    final start = h.lifeEvents.events.values.firstWhere(
      (e) => e.type == LifeEventType.sleepStart,
    );
    expect(wake.timestamp, DateTime(2026, 10, 19, 6, 30));
    expect(start.timestamp, DateTime(2026, 10, 19, 1));
  });

  test('without an advisor the reply is exactly as before', () async {
    final h = await AssistantHarness.create(
      script: (_) => calls([call('logPulse', sleep(3))]),
    );
    final turn = await h.engine.handle('slept 3 hours');
    expect(turn.reply, 'Done. I\'ve logged 3h of sleep.');
  });
}
