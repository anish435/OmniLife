import 'dart:math';

import 'daily_facts.dart';

/// The evidence behind a surfaced pattern, always shown to the user.
class PatternEvidence {
  const PatternEvidence({
    required this.totalDays,
    required this.daysA,
    required this.daysB,
    required this.meanA,
    required this.meanB,
    required this.effectSize,
  });

  final int totalDays;
  final int daysA;
  final int daysB;
  final double meanA;
  final double meanB;

  /// Cohen's d between the two groups (standardised difference).
  final double effectSize;
}

class LifePattern {
  const LifePattern({
    required this.id,
    required this.statement,
    required this.evidenceLine,
    required this.strength,
    this.evidence,
  });

  final String id;

  /// e.g. "On days when you logged 7+ hours of sleep, you completed more
  /// tasks (6.2 vs 3.8)."
  final String statement;

  /// e.g. "Based on 11 days (6 vs 5). An association in your own data,
  /// not proof of cause."
  final String evidenceLine;

  /// Absolute effect size; used only for ordering.
  final double strength;
  final PatternEvidence? evidence;
}

class _Comparison {
  const _Comparison({
    required this.id,
    required this.condA,
    required this.condB,
    required this.higherPhrase,
    required this.lowerPhrase,
    required this.minAbsDiff,
    required this.group,
    required this.outcome,
    required this.fmt,
  });

  final String id;
  final String condA;
  final String condB;
  final String higherPhrase;
  final String lowerPhrase;
  final double minAbsDiff;

  /// true = group A, false = group B, null = day not eligible.
  final bool? Function(DailyFacts) group;
  final double? Function(DailyFacts) outcome;
  final String Function(double) fmt;
}

/// Finds simple associations across recorded days and reports them only
/// when the evidence is strong enough:
///
/// * at least [minTotalDays] eligible days, with at least [minGroupDays]
///   in each group (so one or two days can never produce an "insight");
/// * a standardised difference of at least [minEffectSize] (Cohen's d);
/// * and a practically meaningful absolute difference.
///
/// Wording is always "on days when ... your data shows ..." and every
/// pattern carries its sample size. These are correlations in the user's
/// own entries and never claim a cause or a medical effect.
class PatternDetector {
  const PatternDetector({
    this.minTotalDays = 8,
    this.minGroupDays = 3,
    this.minEffectSize = 0.5,
  });

  final int minTotalDays;
  final int minGroupDays;
  final double minEffectSize;

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  static final List<_Comparison> _comparisons = [
    _Comparison(
      id: 'sleep_tasks',
      condA: 'you logged 7+ hours of sleep',
      condB: 'you slept less',
      higherPhrase: 'you completed more tasks',
      lowerPhrase: 'you completed fewer tasks',
      minAbsDiff: 1,
      group: (d) => d.sleepMinutes == null ? null : d.sleepMinutes! >= 420,
      outcome: (d) => d.tasksCompleted.toDouble(),
      fmt: _num,
    ),
    _Comparison(
      id: 'sleep_focus',
      condA: 'you logged 7+ hours of sleep',
      condB: 'you slept less',
      higherPhrase: 'you recorded more focus time',
      lowerPhrase: 'you recorded less focus time',
      minAbsDiff: 10,
      group: (d) => d.sleepMinutes == null ? null : d.sleepMinutes! >= 420,
      outcome: (d) => d.focusMinutes.toDouble(),
      fmt: (v) => '${_num(v)} min',
    ),
    _Comparison(
      id: 'workout_mood',
      condA: 'you logged a workout',
      condB: 'you did not',
      higherPhrase: 'your mood entries were higher',
      lowerPhrase: 'your mood entries were lower',
      minAbsDiff: 0.5,
      group: (d) => d.averageMood == null ? null : d.workouts > 0,
      outcome: (d) => d.averageMood,
      fmt: (v) => '${_num(v)}/5',
    ),
    _Comparison(
      id: 'focus_tasks',
      condA: 'you logged 45+ minutes of focus',
      condB: 'you logged less',
      higherPhrase: 'you completed more tasks',
      lowerPhrase: 'you completed fewer tasks',
      minAbsDiff: 1,
      group: (d) => d.focusMinutes >= 45,
      outcome: (d) => d.tasksCompleted.toDouble(),
      fmt: _num,
    ),
    _Comparison(
      id: 'workload_energy',
      condA: 'you had 4+ tasks due',
      condB: 'you had fewer',
      higherPhrase: 'your energy entries were higher',
      lowerPhrase: 'your energy entries were lower',
      minAbsDiff: 0.5,
      group: (d) => d.averageEnergy == null ? null : d.tasksDue >= 4,
      outcome: (d) => d.averageEnergy,
      fmt: (v) => '${_num(v)}/5',
    ),
    _Comparison(
      id: 'habits_tasks',
      condA: 'you completed most of your habits',
      condB: 'you completed fewer',
      higherPhrase: 'you completed more tasks',
      lowerPhrase: 'you completed fewer tasks',
      minAbsDiff: 1,
      group: (d) {
        final rate = d.habitCompletionRate;
        return rate == null ? null : rate >= 0.7;
      },
      outcome: (d) => d.tasksCompleted.toDouble(),
      fmt: _num,
    ),
  ];

  List<LifePattern> detect(List<DailyFacts> days) {
    final found = <LifePattern>[];
    for (final c in _comparisons) {
      final p = _evaluate(c, days);
      if (p != null) found.add(p);
    }
    final energy = _lowEnergyWindow(days);
    if (energy != null) found.add(energy);
    found.sort((a, b) => b.strength.compareTo(a.strength));
    return found;
  }

  LifePattern? _evaluate(_Comparison c, List<DailyFacts> days) {
    final a = <double>[], b = <double>[];
    for (final d in days) {
      final g = c.group(d);
      final v = c.outcome(d);
      if (g == null || v == null) continue;
      (g ? a : b).add(v);
    }
    final total = a.length + b.length;
    if (total < minTotalDays ||
        a.length < minGroupDays ||
        b.length < minGroupDays) {
      return null;
    }
    final meanA = _mean(a), meanB = _mean(b);
    final diff = meanA - meanB;
    if (diff.abs() < c.minAbsDiff) return null;

    final pooled = _pooledSd(a, b);
    final d = pooled < 1e-9 ? 5.0 : diff.abs() / pooled;
    if (d < minEffectSize) return null;

    final higher = diff > 0;
    return LifePattern(
      id: c.id,
      statement:
          'On days when ${c.condA}, ${higher ? c.higherPhrase : c.lowerPhrase} '
          '(${c.fmt(meanA)} on average vs ${c.fmt(meanB)} on days when '
          '${c.condB}).',
      evidenceLine:
          'Based on $total days (${a.length} vs ${b.length}). This is an '
          'association in your own entries, not proof of cause.',
      strength: d,
      evidence: PatternEvidence(
        totalDays: total,
        daysA: a.length,
        daysB: b.length,
        meanA: meanA,
        meanB: meanB,
        effectSize: d,
      ),
    );
  }

  LifePattern? _lowEnergyWindow(List<DailyFacts> days) {
    final withEntries = days.where((d) => d.energyEntries.isNotEmpty).toList();
    if (withEntries.length < minTotalDays) return null;
    int bestStart = -1, bestCount = 0;
    for (var start = 6; start <= 20; start += 2) {
      final count = withEntries
          .where(
            (d) => d.energyEntries.any(
              (e) => e.level <= 2 && e.hour >= start && e.hour < start + 2,
            ),
          )
          .length;
      if (count > bestCount) {
        bestCount = count;
        bestStart = start;
      }
    }
    final share = bestCount / withEntries.length;
    if (bestStart < 0 || bestCount < 5 || share < 0.5) return null;
    return LifePattern(
      id: 'low_energy_window',
      statement:
          'On $bestCount of ${withEntries.length} days with energy entries, '
          'you logged low energy between ${_hour(bestStart)} and '
          '${_hour(bestStart + 2)}.',
      evidenceLine:
          'Based on ${withEntries.length} days with energy entries. '
          'This describes when you recorded low energy, not why.',
      strength: share * 2,
    );
  }

  String _hour(int h) {
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 ${h < 12 || h == 24 ? 'AM' : 'PM'}';
  }

  double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;

  double _pooledSd(List<double> a, List<double> b) {
    double ss(List<double> v) {
      final m = _mean(v);
      return v.fold<double>(0, (s, x) => s + pow(x - m, 2));
    }

    final dof = a.length + b.length - 2;
    return dof <= 0 ? 0 : sqrt((ss(a) + ss(b)) / dof);
  }
}
