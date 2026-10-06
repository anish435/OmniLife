// ignore_for_file: prefer_initializing_formals
/// Steps credited by one counter reading.
class StepDelta {
  const StepDelta({
    required this.steps,
    required this.at,
    this.counterReset = false,
    this.discarded = 0,
  });

  /// Steps to add to the bucket for [at] (day + hour).
  final int steps;
  final DateTime at;

  /// True when the cumulative counter went backwards (device reboot) and
  /// the new value was treated as steps since the reset.
  final bool counterReset;

  /// Steps that were seen but not credited because they cannot be placed
  /// in time (see [StepAggregator.maxCatchUpGap]).
  final int discarded;
}

/// Converts the pedometer's cumulative "steps since last boot" counter into
/// per-reading step deltas. Pure and platform-free.
///
/// Rules:
/// * The first reading only sets a baseline (the counter's absolute value
///   says nothing about today).
/// * Counter increases: credit the difference.
/// * Counter decreases: the device rebooted and the sensor restarted at 0,
///   so the new value is the number of steps since the reset; credit it.
///   (This also means a reboot is never mistaken for negative steps.)
/// * Catch-up limit: when the app was not receiving readings, the steps
///   accumulated in the gap cannot be assigned to a time. They are credited
///   only if the previous reading was on the same calendar day and at most
///   [maxCatchUpGap] ago; otherwise they are discarded (reported in
///   [StepDelta.discarded]) so a day's total is never inflated by steps
///   taken yesterday while the app was closed.
class StepAggregator {
  StepAggregator({
    int? lastCounter,
    DateTime? lastReadingAt,
    this.maxCatchUpGap = const Duration(hours: 12),
  }) : _lastCounter = lastCounter,
       _lastReadingAt = lastReadingAt;

  final Duration maxCatchUpGap;

  int? _lastCounter;
  DateTime? _lastReadingAt;

  /// Persist these two values and pass them back to the constructor after
  /// a restart so a delta survives app restarts.
  int? get lastCounter => _lastCounter;
  DateTime? get lastReadingAt => _lastReadingAt;

  /// Feeds one counter reading. Returns null when nothing was credited and
  /// nothing was discarded (baseline, duplicate, invalid value).
  StepDelta? ingest(int counter, DateTime at) {
    if (counter < 0) return null;
    final last = _lastCounter;
    final lastAt = _lastReadingAt;
    _lastCounter = counter;
    _lastReadingAt = at;
    if (last == null || lastAt == null) return null;
    if (counter == last) return null;

    final reset = counter < last;
    final raw = reset ? counter : counter - last;
    if (raw == 0) return null;

    final gap = at.difference(lastAt);
    final sameDay =
        lastAt.year == at.year &&
        lastAt.month == at.month &&
        lastAt.day == at.day;
    if (!sameDay || gap > maxCatchUpGap || gap.isNegative) {
      return StepDelta(steps: 0, at: at, counterReset: reset, discarded: raw);
    }
    return StepDelta(steps: raw, at: at, counterReset: reset);
  }
}
