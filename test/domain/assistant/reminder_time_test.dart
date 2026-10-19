import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/assistant/reminder_time.dart';
import 'package:omnilife/domain/assistant/tool_args.dart';
import 'package:omnilife/domain/assistant/when_format.dart';
import 'package:omnilife/domain/entities/reminder.dart';

void main() {
  // Monday 19 Oct 2026, 14:05.
  final now = DateTime(2026, 10, 19, 14, 5);
  final resolver = ReminderTimeResolver(now);

  ParsedWhen? at(String? s) =>
      s == null ? null : ToolArgs.parseWhen(s, now: now);

  group('repeat detection', () {
    for (final t in [
      'remind me daily to stretch',
      'every day at 8 take vitamins',
      'each day at noon',
      'remind me everyday',
      'every morning at 7',
      'every night before bed',
      'each evening',
    ]) {
      test('daily: $t', () {
        expect(ReminderTimeResolver.detectRepeat(t), ReminderRepeat.daily);
      });
    }

    for (final t in [
      'weekly review on friday',
      'every week',
      'every monday at 9',
      'every Tuesday morning',
      'every sat',
    ]) {
      test('weekly: $t', () {
        expect(ReminderTimeResolver.detectRepeat(t), ReminderRepeat.weekly);
      });
    }

    for (final t in [
      'remind me to take tablets tonight',
      'remind me tomorrow morning to call',
      'at 6 pm call mum',
      'remind me on friday',
    ]) {
      test('once: $t', () {
        expect(ReminderTimeResolver.detectRepeat(t), ReminderRepeat.none);
      });
    }
  });

  group('day-part defaults', () {
    test('tonight is 9 PM today', () {
      final r = resolver.resolve(
        at: at('2026-10-19T20:00'),
        utterance: 'remind me to take tablets tonight',
      );
      expect(r.at, DateTime(2026, 10, 19, 21));
      expect(r.repeat, ReminderRepeat.none);
    });

    test('morning 8 AM, afternoon 2 PM, evening 6 PM', () {
      DateTime go(String said, String guess) =>
          resolver.resolve(at: at(guess), utterance: said).at;
      expect(
        go('remind me tomorrow morning to call', '2026-10-20'),
        DateTime(2026, 10, 20, 8),
      );
      expect(
        go('tomorrow afternoon call', '2026-10-20T13:00'),
        DateTime(2026, 10, 20, 14),
      );
      expect(
        go('this evening water plants', '2026-10-19T19:00'),
        DateTime(2026, 10, 19, 18),
      );
    });

    test('an explicit clock time beats the day-part default', () {
      final r = resolver.resolve(
        at: at('2026-10-19T22:30'),
        utterance: 'tonight at 10:30 take pills',
      );
      expect(r.at, DateTime(2026, 10, 19, 22, 30));
    });

    test('day part with no model time still works', () {
      final r = resolver.resolve(utterance: 'remind me tonight to lock up');
      expect(r.at, DateTime(2026, 10, 19, 21));
    });

    test('no time at all asks a follow-up', () {
      expect(
        () => resolver.resolve(
          at: at('2026-10-20'),
          utterance: 'remind me tomorrow to call',
        ),
        throwsA(isA<ToolFollowUp>()),
      );
      expect(
        () => resolver.resolve(utterance: 'remind me to call'),
        throwsA(isA<ToolFollowUp>()),
      );
    });
  });

  group('time already passed', () {
    test('one-off with only a time moves to tomorrow', () {
      final r = resolver.resolve(
        at: at('08:00'),
        utterance: 'remind me at 8 to stretch',
      );
      expect(r.at, DateTime(2026, 10, 20, 8));
      expect(r.repeat, ReminderRepeat.none);
    });

    test('model-supplied same-day past time also moves to tomorrow', () {
      final r = resolver.resolve(
        at: at('2026-10-19T09:00'),
        utterance: 'remind me at 9',
      );
      expect(r.at, DateTime(2026, 10, 20, 9));
    });

    test('later today stays today', () {
      final r = resolver.resolve(
        at: at('18:30'),
        utterance: 'remind me at 6:30 pm',
      );
      expect(r.at, DateTime(2026, 10, 19, 18, 30));
    });

    test('daily whose time passed starts tomorrow', () {
      final r = resolver.resolve(
        at: at('2026-10-19T08:00'),
        utterance: 'daily at 8 vitamins',
      );
      expect(r.at, DateTime(2026, 10, 20, 8));
      expect(r.repeat, ReminderRepeat.daily);
    });

    test('a past date on an earlier day is refused for one-offs', () {
      expect(
        () => resolver.resolve(
          at: at('2026-10-10T09:00'),
          utterance: 'remind me at 9',
        ),
        throwsA(isA<ToolFollowUp>()),
      );
    });

    test('a past start date for a daily reminder rolls forward', () {
      final r = resolver.resolve(
        at: at('2026-10-10T09:00'),
        utterance: 'every day at 9',
      );
      expect(r.at, DateTime(2026, 10, 20, 9));
    });
  });

  test('utterance decides repeat; args only when there is no utterance', () {
    expect(
      resolver
          .resolve(
            at: at('2026-10-21T08:00'),
            utterance: 'remind me on wednesday at 8',
            argRepeat: ReminderRepeat.daily,
          )
          .repeat,
      ReminderRepeat.none,
    );
    expect(
      resolver
          .resolve(at: at('2026-10-21T08:00'), argRepeat: ReminderRepeat.weekly)
          .repeat,
      ReminderRepeat.weekly,
    );
  });

  group('wording', () {
    test('describeWhen', () {
      expect(describeWhen(DateTime(2026, 10, 19, 21), now), 'today 9:00 PM');
      expect(
        describeWhen(DateTime(2026, 10, 20, 8, 30), now),
        'tomorrow 8:30 AM',
      );
      expect(
        describeWhen(DateTime(2026, 10, 23, 0, 5), now),
        'Fri 23 Oct 12:05 AM',
      );
    });

    test('spokenWhen', () {
      expect(spokenWhen(DateTime(2026, 10, 19, 21), now), '9 PM tonight');
      expect(spokenWhen(DateTime(2026, 10, 19, 15), now), '3 PM today');
      expect(spokenWhen(DateTime(2026, 10, 20, 8), now), '8 AM tomorrow');
      expect(
        spokenWhen(DateTime(2026, 10, 23, 18, 30), now),
        '6:30 PM on Fri 23 Oct',
      );
    });

    test('formatAmount', () {
      expect(formatAmount(200), '200');
      expect(formatAmount(1234567), '1,234,567');
      expect(formatAmount(12.5), '12.50');
    });
  });
}
