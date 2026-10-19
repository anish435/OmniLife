import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/insights/advice_context.dart';
import 'package:omnilife/domain/insights/linked_advice_rules.dart';
import 'package:omnilife/domain/insights/linked_advisor.dart';
import 'package:omnilife/domain/insights/logged_fact.dart';
import 'package:omnilife/domain/insights/text_hash.dart';
import 'package:omnilife/domain/services/pulse/daily_facts.dart';

DailyFacts _day(DateTime d, {int? sleep, int water = 0}) => DailyFacts(d)
  ..sleepMinutes = sleep
  ..waterMl = water;

AdviceContext _ctx(
  List<LoggedFact> logged, {
  int hour = 11,
  int todayWater = 0,
  List<int?> priorSleep = const [],
}) {
  final now = DateTime(2026, 10, 19, hour, 5);
  final today = DateTime(2026, 10, 19);
  return AdviceContext.fromFacts(
    now: now,
    logged: logged,
    days: [
      _day(today, water: todayWater),
      for (var i = 0; i < priorSleep.length; i++)
        _day(today.subtract(Duration(days: i + 1)), sleep: priorSleep[i]),
    ],
  );
}

class _Provider implements AiProvider, TextCompleter {
  _Provider(this.reply, {this.configured = true});
  final String? reply;
  final bool configured;
  var calls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  }) async => const AiResponse();

  @override
  Future<String?> complete({
    required List<AiMessage> messages,
    int maxTokens = 400,
  }) async {
    calls++;
    return reply;
  }
}

void main() {
  const rules = LinkedAdviceRules();

  group('rules', () {
    test('low sleep with decent water connects the two with real numbers', () {
      final a = rules.evaluate(
        _ctx([
          const LoggedFact(LoggedKind.sleep, value: 180),
          const LoggedFact(LoggedKind.water, value: 2000),
        ], todayWater: 2000),
      )!;
      expect(a.key, 'low_sleep_water_ok');
      expect(a.text, contains('Water\'s good at 2 L'));
      expect(a.text, contains('only 3h of sleep'));
      expect(a.text, contains('caffeine after 2 PM'));
      expect(a.text, contains('10:30'));
      expect(a.text, contains('reminder at 10 PM'));
      // Suggestion wording only.
      expect(a.text, isNot(matches(RegExp('because|cause|diagnos'))));
    });

    test('low sleep with low water mentions both', () {
      final a = rules.evaluate(
        _ctx(
          [
            const LoggedFact(LoggedKind.sleep, value: 240),
            const LoggedFact(LoggedKind.water, value: 500),
          ],
          hour: 15,
          todayWater: 500,
        ),
      )!;
      expect(a.key, 'low_sleep_low_water');
      expect(a.text, contains('500 ml'));
      expect(a.text, contains('4h'));
      // After 2 PM the caffeine line changes rather than naming 2 PM.
      expect(a.text, isNot(contains('after 2 PM')));
    });

    test('low sleep alone still gets one useful line', () {
      final a = rules.evaluate(
        _ctx([const LoggedFact(LoggedKind.sleep, value: 200)]),
      )!;
      expect(a.key, 'low_sleep');
      expect(a.text, contains('3h 20m'));
    });

    test('recent short nights are used as context', () {
      final a = rules.evaluate(
        _ctx(
          [const LoggedFact(LoggedKind.sleep, value: 200)],
          priorSleep: [300, 320, 310, null, 330],
        ),
      )!;
      expect(a.text, contains('last few nights have averaged'));
    });

    test('a heavy workout after a short night suggests going lighter', () {
      final a = rules.evaluate(
        _ctx([
          const LoggedFact(LoggedKind.sleep, value: 240),
          const LoggedFact(LoggedKind.workout, value: 45),
        ]),
      )!;
      expect(a.text, contains('lighter session'));
    });

    test('nothing noteworthy means no advice at all', () {
      // Slept well and drank plenty: no filler.
      expect(
        rules.evaluate(
          _ctx([
            const LoggedFact(LoggedKind.sleep, value: 450),
            const LoggedFact(LoggedKind.water, value: 2000),
          ], todayWater: 2000),
        ),
        isNull,
      );
      // Water alone, early in the day.
      expect(
        rules.evaluate(
          _ctx([
            const LoggedFact(LoggedKind.water, value: 250),
          ], todayWater: 250),
        ),
        isNull,
      );
      expect(rules.evaluate(_ctx([const LoggedFact(LoggedKind.meal)])), isNull);
      expect(
        rules.evaluate(_ctx([const LoggedFact(LoggedKind.mood, value: 4)])),
        isNull,
      );
      // Empty days, nothing logged.
      expect(rules.evaluate(_ctx(const [])), isNull);
    });

    test('low energy with short recent nights points at an earlier night', () {
      final a = rules.evaluate(
        _ctx(
          [const LoggedFact(LoggedKind.energy, value: 2)],
          priorSleep: [320, 330, 300],
        ),
      )!;
      expect(a.key, 'low_feeling_short_week');
      expect(a.text, contains('5h'));
    });

    test('long workout with little water is flagged, with the numbers', () {
      final a = rules.evaluate(
        _ctx([
          const LoggedFact(LoggedKind.workout, value: 75),
        ], todayWater: 300),
      )!;
      expect(a.key, 'long_workout_low_water');
      expect(a.text, contains('75 min'));
      expect(a.text, contains('300 ml'));
    });

    test('no reminder offer late in the evening', () {
      final a = rules.evaluate(
        _ctx([const LoggedFact(LoggedKind.sleep, value: 200)], hour: 22),
      )!;
      expect(a.text, isNot(contains('Want a reminder')));
    });
  });

  group('context and cache keys', () {
    test('summary is stable and changes with the data', () {
      final a = _ctx([const LoggedFact(LoggedKind.sleep, value: 180)]);
      final b = _ctx([const LoggedFact(LoggedKind.sleep, value: 180)]);
      final c = _ctx([const LoggedFact(LoggedKind.sleep, value: 200)]);
      expect(stableHash(a.summary()), stableHash(b.summary()));
      expect(stableHash(a.summary()), isNot(stableHash(c.summary())));
      expect(a.summary().length, lessThan(600));
    });

    test('unlogged days do not drag the averages down', () {
      final c = _ctx(const [], priorSleep: [360, null, null, 420]);
      expect(c.week.sleepDays, 2);
      expect(c.week.averageSleepMinutes, 390);
    });
  });

  group('advisor', () {
    final now = DateTime(2026, 10, 19, 11, 5);
    final facts = [
      const LoggedFact(LoggedKind.sleep, value: 180),
      const LoggedFact(LoggedKind.water, value: 2000),
    ];
    Future<List<DailyFacts>> days() async => [
      _day(DateTime(2026, 10, 19), water: 2000, sleep: 180),
    ];

    test(
      'skips (and never calls the model) when there is nothing to say',
      () async {
        final p = _Provider('should not be used');
        final advisor = DefaultLinkedAdvisor(
          loadDays: () async => [_day(DateTime(2026, 10, 19), water: 2000)],
          provider: () => p,
        );
        final text = await advisor.advise(
          facts: [
            const LoggedFact(LoggedKind.sleep, value: 450),
            const LoggedFact(LoggedKind.water, value: 2000),
          ],
          now: now,
          modelText: 'Great job, stay hydrated! You slept 7h and drank 2000.',
        );
        expect(text, isNull);
        expect(p.calls, 0);
      },
    );

    test('works without a key using the rule text', () async {
      final advisor = DefaultLinkedAdvisor(
        loadDays: days,
        provider: () => _Provider(null, configured: false),
      );
      final text = await advisor.advise(facts: facts, now: now);
      expect(text, contains('only 3h of sleep'));
    });

    test('reuses a good model text from the tool-calling reply', () async {
      final p = _Provider('unused');
      final advisor = DefaultLinkedAdvisor(loadDays: days, provider: () => p);
      final text = await advisor.advise(
        facts: facts,
        now: now,
        modelText:
            'Water\'s good at 2 L. With 3h of sleep, maybe go easy on '
            'caffeine this afternoon. Want a reminder at 10 PM?',
      );
      expect(text, contains('Water\'s good at 2 L'));
      expect(p.calls, 0);
    });

    test('rejects filler or medical-sounding model text', () async {
      final p = _Provider(null);
      final advisor = DefaultLinkedAdvisor(loadDays: days, provider: () => p);
      for (final bad in [
        'Logged that for you!',
        'Remember to stay hydrated and sleep well, you slept 3 hours.',
        'Sleeping 3h causes fatigue and may signal a sleep disorder.',
      ]) {
        final text = await advisor.advise(
          facts: facts,
          now: now,
          modelText: bad,
        );
        expect(text, isNot(bad));
        expect(text, contains('only 3h of sleep'));
      }
    });

    test('one compact extra call, cached by context hash', () async {
      final p = _Provider(
        'Water\'s good at 2 L, but 3h of sleep is short, so maybe keep '
        'caffeine early today. Want a reminder at 10 PM?',
      );
      final cache = InMemoryTextCache();
      final advisor = DefaultLinkedAdvisor(
        loadDays: days,
        provider: () => p,
        cache: cache,
      );
      final first = await advisor.advise(facts: facts, now: now);
      final second = await advisor.advise(facts: facts, now: now);
      expect(first, second);
      expect(first, contains('keep caffeine early'));
      expect(p.calls, 1);
      expect(cache.store, hasLength(1));
    });

    test(
      'a failed or unusable extra call falls back to the rule text',
      () async {
        final p = _Provider('ok');
        final advisor = DefaultLinkedAdvisor(loadDays: days, provider: () => p);
        final text = await advisor.advise(facts: facts, now: now);
        expect(text, contains('only 3h of sleep'));
      },
    );

    test(
      'a failing Pulse load still gives advice from what was said',
      () async {
        final advisor = DefaultLinkedAdvisor(
          loadDays: () async => throw StateError('offline'),
        );
        final text = await advisor.advise(
          facts: [const LoggedFact(LoggedKind.sleep, value: 180)],
          now: now,
        );
        expect(text, contains('3h'));
      },
    );
  });
}
