import 'advice_context.dart';
import 'logged_fact.dart';

class LinkedAdvice {
  const LinkedAdvice(this.key, this.text);

  /// Which rule fired (stable, for tests and caching).
  final String key;
  final String text;
}

/// Deterministic "connect the dots" advice for what the user just logged.
///
/// Wording is suggestion and correlation only: "may", "could", "worth
/// trying". Nothing medical, nothing causal. Returns null when there is
/// nothing useful to say, so a fine day never gets filler.
class LinkedAdviceRules {
  const LinkedAdviceRules();

  static const lowSleepMinutes = 330; // under 5.5 hours
  static const lowEnergy = 2;

  LinkedAdvice? evaluate(AdviceContext c) {
    if (c.logged.isEmpty) return null;

    final sleep = c.latest(LoggedKind.sleep);
    final waterLogged = c.has(LoggedKind.water);
    final waterToday = c.today.waterMl;
    final workout = c.latest(LoggedKind.workout);
    final energy = c.latest(LoggedKind.energy);
    final mood = c.latest(LoggedKind.mood);
    final hour = c.now.hour;

    final waterGood = waterLogged && waterToday >= 1500;
    // By mid-afternoon under a litre is worth a mention.
    final waterLow = waterToday < 1000 && hour >= 14;

    if (sleep != null && sleep < lowSleepMinutes) {
      return _lowSleep(c, sleep, waterGood, waterLogged && waterLow, workout);
    }

    final lowFeeling =
        (energy != null && energy <= lowEnergy) ||
        (mood != null && mood <= lowEnergy);
    final shortWeek = _shortWeek(c);
    if (lowFeeling) {
      final which = (energy != null && energy <= lowEnergy)
          ? 'Energy\'s low'
          : 'Mood\'s low';
      if (shortWeek != null) {
        return LinkedAdvice(
          'low_feeling_short_week',
          '$which, and your logged nights have averaged '
              '${formatMinutes(shortWeek)} lately. An earlier night could be '
              'worth trying.${_reminderOffer(c)}',
        );
      }
      if (waterLow) {
        return LinkedAdvice(
          'low_feeling_low_water',
          '$which and I only see ${_water(waterToday)} of water today. '
              'A glass now and a short walk may be a gentle place to start.',
        );
      }
      return null;
    }

    if (workout != null && workout >= 60 && waterToday < 1000) {
      return LinkedAdvice(
        'long_workout_low_water',
        'That was a long workout ($workout min) and I only see '
            '${_water(waterToday)} of water today. A couple of glasses over the '
            'next hour could be a good idea.',
      );
    }

    if (waterLogged && waterLow && c.logged.length == 1) {
      final usual = c.week.averageWaterMl;
      final tail = usual == null
          ? 'A glass with each of your next meals would get you further.'
          : 'Your recent days averaged ${_water(usual)}, so a glass with '
                'each of your next meals would get you closer.';
      return LinkedAdvice(
        'low_water_afternoon',
        'That brings you to ${_water(waterToday)} today. $tail',
      );
    }
    return null;
  }

  LinkedAdvice _lowSleep(
    AdviceContext c,
    int sleep,
    bool waterGood,
    bool waterLow,
    int? workout,
  ) {
    final hour = c.now.hour;
    final slept = formatMinutes(sleep);
    final parts = <String>[];

    if (waterGood) {
      parts.add('Water\'s good at ${_water(c.today.waterMl)}.');
    } else if (waterLow) {
      parts.add(
        'Only ${_water(c.today.waterMl)} of water so far, so a glass now '
        'could help.',
      );
    }

    final caffeine = hour < 14
        ? 'go easy on caffeine after 2 PM'
        : 'it may be worth skipping more caffeine today';
    final bed = hour < 22
        ? 'aim for bed by 10:30 tonight'
        : 'try to get to bed early tomorrow';
    parts.add('With only $slept of sleep, $caffeine and $bed.');

    final shortWeek = _shortWeek(c);
    if (shortWeek != null && shortWeek < lowSleepMinutes + 60) {
      parts.add(
        'Your last few nights have averaged ${formatMinutes(shortWeek)} too.',
      );
    }
    if (workout != null && workout >= 30) {
      parts.add('A lighter session than usual may suit a short night.');
    }
    final text = '${parts.take(3).join(' ')}${_reminderOffer(c)}';
    return LinkedAdvice(
      waterGood
          ? 'low_sleep_water_ok'
          : (waterLow ? 'low_sleep_low_water' : 'low_sleep'),
      text,
    );
  }

  /// Average of recent nights when there are enough and they run short.
  int? _shortWeek(AdviceContext c) {
    final w = c.week;
    if (w.sleepDays >= 3 &&
        w.averageSleepMinutes != null &&
        w.averageSleepMinutes! < 360) {
      return w.averageSleepMinutes;
    }
    return null;
  }

  String _reminderOffer(AdviceContext c) =>
      c.now.hour < 21 ? ' Want a reminder at 10 PM?' : '';

  String _water(int ml) {
    if (ml < 1000) return '$ml ml';
    final l = ml / 1000;
    final text = l == l.roundToDouble()
        ? l.round().toString()
        : l.toStringAsFixed(1);
    return '$text L';
  }
}
