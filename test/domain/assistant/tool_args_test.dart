import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/assistant/tool_args.dart';

void main() {
  final now = DateTime(2026, 10, 19, 14, 5);

  test('string trims, rejects wrong types and long text', () {
    expect(const ToolArgs({'a': '  hi '}).string('a'), 'hi');
    expect(const ToolArgs({}).string('a'), isNull);
    expect(const ToolArgs({'a': '  '}).string('a'), isNull);
    expect(
      () => const ToolArgs({}).string('a', required: true),
      throwsA(isA<ToolArgException>()),
    );
    expect(
      () => const ToolArgs({
        'a': [1],
      }).string('a'),
      throwsA(isA<ToolArgException>()),
    );
    expect(
      () => ToolArgs({'a': 'x' * 300}).string('a'),
      throwsA(isA<ToolArgException>()),
    );
  });

  test('number accepts numeric strings and enforces range', () {
    expect(const ToolArgs({'n': '1,200.5'}).number('n'), 1200.5);
    expect(const ToolArgs({'n': 3}).number('n', min: 1, max: 5), 3);
    expect(
      () => const ToolArgs({'n': 'abc'}).number('n'),
      throwsA(isA<ToolArgException>()),
    );
    expect(
      () => const ToolArgs({'n': 9}).number('n', max: 5),
      throwsA(isA<ToolArgException>()),
    );
    expect(
      () => const ToolArgs({'n': double.nan}).number('n'),
      throwsA(isA<ToolArgException>()),
    );
    expect(
      () => const ToolArgs({}).number('n', required: true),
      throwsA(isA<ToolArgException>()),
    );
  });

  test('oneOf is case-insensitive and rejects unknown values', () {
    expect(
      const ToolArgs({'k': 'Daily'}).oneOf('k', ['none', 'daily']),
      'daily',
    );
    expect(const ToolArgs({}).oneOf('k', ['none']), isNull);
    expect(
      () => const ToolArgs({'k': 'hourly'}).oneOf('k', ['none', 'daily']),
      throwsA(isA<ToolArgException>()),
    );
  });

  test('boolean accepts bools and yes/no strings', () {
    expect(const ToolArgs({'b': true}).boolean('b'), isTrue);
    expect(const ToolArgs({'b': 'No'}).boolean('b'), isFalse);
    expect(const ToolArgs({'b': 'maybe'}).boolean('b'), isNull);
  });

  group('when', () {
    test('local date-time, date only, time only', () {
      final dt = ToolArgs.parseWhen('2026-10-19T21:00');
      expect(
        (dt.value, dt.hasDate, dt.hasTime),
        (DateTime(2026, 10, 19, 21), true, true),
      );

      final d = ToolArgs.parseWhen('2026-10-20');
      expect((d.hasDate, d.hasTime), (true, false));

      final t = ToolArgs.parseWhen('08:30', now: now);
      expect(
        (t.value, t.hasDate, t.hasTime),
        (DateTime(2026, 10, 19, 8, 30), false, true),
      );
    });

    test('UTC input is converted to local', () {
      final u = ToolArgs.parseWhen('2026-10-19T21:00:00Z');
      expect(u.value.isUtc, isFalse);
      expect(u.value.toUtc(), DateTime.utc(2026, 10, 19, 21));
    });

    test('garbage, impossible times and silly years are rejected', () {
      for (final bad in [
        'tomorrow',
        '25:00',
        '12:75',
        '1850-01-01',
        '2999-01-01',
        'abc',
      ]) {
        expect(
          () => ToolArgs.parseWhen(bad),
          throwsA(isA<ToolArgException>()),
          reason: bad,
        );
      }
      expect(
        () => const ToolArgs({'w': 5}).when('w'),
        throwsA(isA<ToolArgException>()),
      );
    });
  });
}
