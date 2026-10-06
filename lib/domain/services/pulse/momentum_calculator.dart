import 'dart:math';

import 'daily_facts.dart';

/// One measurable input to a metric, shown to the user so every score is
/// explainable ("Average focus: 41 min/day").
class MetricComponent {
  const MetricComponent(this.name, this.value, this.unit, {this.previous});

  final String name;
  final double value;
  final String unit;

  /// Same component over the previous window, when available.
  final double? previous;

  double? get change => previous == null ? null : value - previous!;
}

class MetricResult {
  const MetricResult({
    required this.key,
    required this.label,
    required this.score,
    required this.explanation,
    required this.components,
    required this.whyChanged,
    this.previousScore,
    this.missingReason,
  });

  final String key;
  final String label;

  /// 0-100, or null when there is not enough recorded data to say anything.
  final int? score;
  final int? previousScore;
  final String explanation;
  final List<MetricComponent> components;

  /// Plain-language reasons the score moved versus the previous window.
  final List<String> whyChanged;

  /// Set when [score] is null: what the user needs to record.
  final String? missingReason;

  bool get hasEnoughData => score != null;
  int? get delta =>
      score != null && previousScore != null ? score! - previousScore! : null;
}

class MomentumReport {
  const MomentumReport({
    required this.focus,
    required this.recovery,
    required this.momentum,
    required this.balance,
  });

  final MetricResult focus;
  final MetricResult recovery;
  final MetricResult momentum;
  final MetricResult balance;

  List<MetricResult> get all => [focus, recovery, momentum, balance];
}

class _Raw {
  const _Raw(this.score, this.components, this.explanation, [this.missing]);
  final int? score;
  final List<MetricComponent> components;
  final String explanation;
  final String? missing;
}

/// Computes the four OmniPulse dimensions from recorded [DailyFacts].
///
/// Every number is a documented formula over the user's own entries - no
/// opaque score:
///
/// * **Focus** = average focus minutes per day over the last 7 days divided
///   by a daily target (default 60), capped at 100.
/// * **Recovery** = 70% sleep-duration adequacy (average sleep / 7.5 h,
///   capped at 100) + 30% bedtime regularity (100 when the bedtime standard
///   deviation is 30 min or less, falling linearly to 0 at 120 min).
///   Needs at least 3 recorded nights.
/// * **Momentum** = share of the last 14 days on which the user did or
///   logged something, with recent days weighted up to twice as much.
/// * **Balance** = how evenly the last 7 days of actions spread across
///   Work (tasks, focus), Health (sleep, workouts, water, meals) and Mind
///   (habits, mood/energy check-ins), as normalised entropy. Needs at
///   least 6 actions.
///
/// Each metric is also computed for the preceding window so the report can
/// say which component moved and by how much.
class MomentumCalculator {
  const MomentumCalculator({
    this.focusTargetMinutes = 60,
    this.sleepTargetMinutes = 450,
  });

  final int focusTargetMinutes;
  final int sleepTargetMinutes;

  /// [days] must be consecutive, oldest first, ending on the day to score.
  /// Provide at least 28 days to get previous-window comparisons.
  MomentumReport compute(List<DailyFacts> days) {
    final cur7 = _tail(days, 7, 0);
    final prev7 = _tail(days, 7, 7);
    final cur14 = _tail(days, 14, 0);
    final prev14 = _tail(days, 14, 14);

    return MomentumReport(
      focus: _result(
        'focus',
        'Focus',
        _focus(cur7),
        prev7.isEmpty ? null : _focus(prev7),
      ),
      recovery: _result(
        'recovery',
        'Recovery',
        _recovery(cur7),
        prev7.isEmpty ? null : _recovery(prev7),
      ),
      momentum: _result(
        'momentum',
        'Momentum',
        _momentum(cur14),
        prev14.isEmpty ? null : _momentum(prev14),
      ),
      balance: _result(
        'balance',
        'Balance',
        _balance(cur7),
        prev7.isEmpty ? null : _balance(prev7),
      ),
    );
  }

  List<DailyFacts> _tail(List<DailyFacts> days, int length, int skip) {
    final end = days.length - skip;
    final start = end - length;
    if (start < 0 || end <= 0) return const [];
    return days.sublist(start, end);
  }

  _Raw _focus(List<DailyFacts> w) {
    final total = w.fold<int>(0, (s, d) => s + d.focusMinutes);
    final avg = total / w.length;
    final daysWith = w.where((d) => d.focusSessions > 0).length;
    final anyData = w.any((d) => d.hasAction);
    if (!anyData) {
      return const _Raw(
        null,
        [],
        '',
        'Log a focus session or any activity to see Focus.',
      );
    }
    final score = min(100, (avg / focusTargetMinutes * 100).round());
    return _Raw(
      score,
      [
        MetricComponent('Average focus', avg, 'min/day'),
        MetricComponent(
          'Days with a focus session',
          daysWith.toDouble(),
          'days',
        ),
      ],
      'Average focus time over the last ${w.length} days, compared with a '
      '$focusTargetMinutes-minute daily target.',
    );
  }

  _Raw _recovery(List<DailyFacts> w) {
    final nights = w.where((d) => d.sleepMinutes != null).toList();
    if (nights.length < 3) {
      return _Raw(
        null,
        const [],
        '',
        'Record sleep and wake on at least 3 nights '
            '(${nights.length} of 3 so far).',
      );
    }
    final avgSleep =
        nights.fold<int>(0, (s, d) => s + d.sleepMinutes!) / nights.length;
    final durationScore = min(100.0, avgSleep / sleepTargetMinutes * 100);

    final beds = nights
        .map((d) => d.bedtimeMinutesFromNoon)
        .whereType<int>()
        .map((m) => m.toDouble())
        .toList();
    double? std;
    if (beds.length >= 3) {
      final mean = beds.reduce((a, b) => a + b) / beds.length;
      std = sqrt(
        beds.map((b) => pow(b - mean, 2)).reduce((a, b) => a + b) / beds.length,
      );
    }
    final regularity = std == null
        ? null
        : (100 - ((std - 30) / 90).clamp(0, 1) * 100);
    final score = regularity == null
        ? durationScore.round()
        : (0.7 * durationScore + 0.3 * regularity).round();
    return _Raw(
      score,
      [
        MetricComponent('Average sleep', avgSleep, 'min'),
        if (std != null) MetricComponent('Bedtime variation', std, 'min'),
        MetricComponent('Nights recorded', nights.length.toDouble(), 'nights'),
      ],
      'Recorded sleep averaged against a ${sleepTargetMinutes ~/ 60}h '
      '${sleepTargetMinutes % 60}m target'
      '${regularity == null ? '' : ', plus how regular your bedtime was'}. '
      'Based on your own entries, not a medical measurement.',
    );
  }

  _Raw _momentum(List<DailyFacts> w) {
    if (w.length < 7) {
      return const _Raw(null, [], '', 'Needs at least a week of history.');
    }
    var weighted = 0.0, totalWeight = 0.0;
    var active = 0;
    for (var i = 0; i < w.length; i++) {
      final weight = 1 + i / (w.length - 1);
      totalWeight += weight;
      if (w[i].hasAction) {
        weighted += weight;
        active++;
      }
    }
    if (active == 0) {
      return const _Raw(
        null,
        [],
        '',
        'Log something to start building Momentum.',
      );
    }
    var run = 0;
    for (var i = w.length - 1; i >= 0 && w[i].hasAction; i--) {
      run++;
    }
    return _Raw(
      (weighted / totalWeight * 100).round(),
      [
        MetricComponent('Active days', active.toDouble(), 'of ${w.length}'),
        MetricComponent('Current run', run.toDouble(), 'days'),
      ],
      'Share of the last ${w.length} days on which you completed or logged '
      'something. Recent days count up to twice as much.',
    );
  }

  _Raw _balance(List<DailyFacts> w) {
    var work = 0, health = 0, mind = 0;
    for (final d in w) {
      work += d.tasksCompleted + d.focusSessions;
      health +=
          (d.sleepMinutes != null ? 1 : 0) +
          d.workouts +
          (d.waterMl > 0 ? 1 : 0) +
          d.meals;
      mind += d.habitsDone + d.checkIns;
    }
    final total = work + health + mind;
    if (total < 6) {
      return _Raw(
        null,
        const [],
        '',
        'Needs at least 6 recorded actions in a week ($total so far).',
      );
    }
    var entropy = 0.0;
    for (final c in [work, health, mind]) {
      if (c == 0) continue;
      final p = c / total;
      entropy -= p * log(p) / ln2;
    }
    final score = (entropy / (log(3) / ln2) * 100).round();
    return _Raw(
      score,
      [
        MetricComponent('Work', work / total * 100, '% of actions'),
        MetricComponent('Health', health / total * 100, '% of actions'),
        MetricComponent('Mind', mind / total * 100, '% of actions'),
      ],
      'How evenly your recent actions spread across Work (tasks, focus), '
      'Health (sleep, workouts, water, meals) and Mind (habits, check-ins). '
      '100 means perfectly even; it is not a judgement of any one area.',
    );
  }

  MetricResult _result(String key, String label, _Raw cur, _Raw? prev) {
    final withPrev = [
      for (final c in cur.components)
        MetricComponent(
          c.name,
          c.value,
          c.unit,
          previous: prev?.components
              .where((p) => p.name == c.name)
              .map((p) => p.value)
              .firstOrNull,
        ),
    ];
    return MetricResult(
      key: key,
      label: label,
      score: cur.score,
      previousScore: prev?.score,
      explanation: cur.explanation,
      components: withPrev,
      whyChanged: cur.score == null ? const [] : _why(withPrev),
      missingReason: cur.missing,
    );
  }

  List<String> _why(List<MetricComponent> comps) {
    final moved =
        comps.where((c) => c.change != null && c.change!.abs() >= 0.5).toList()
          ..sort((a, b) => _relative(b).compareTo(_relative(a)));
    return [
      for (final c in moved.take(3))
        '${c.name} ${c.change! > 0 ? 'rose' : 'fell'} from '
            '${_fmt(c.previous!)} to ${_fmt(c.value)} ${c.unit}',
    ];
  }

  double _relative(MetricComponent c) {
    final prev = c.previous ?? 0;
    return (c.change ?? 0).abs() / (prev.abs() < 1 ? 1 : prev.abs());
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
