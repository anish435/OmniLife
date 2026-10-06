import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/sensors/step_aggregator.dart';

void main() {
  final t0 = DateTime(2026, 3, 10, 9);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  test('first reading is only a baseline', () {
    final agg = StepAggregator();
    expect(agg.ingest(5000, at(0)), isNull);
    expect(agg.lastCounter, 5000);
  });

  test('increases are credited as differences', () {
    final agg = StepAggregator();
    agg.ingest(5000, at(0));
    expect(agg.ingest(5120, at(5))!.steps, 120);
    expect(agg.ingest(5121, at(6))!.steps, 1);
  });

  test('an unchanged counter credits nothing', () {
    final agg = StepAggregator();
    agg.ingest(100, at(0));
    expect(agg.ingest(100, at(1)), isNull);
  });

  test('reboot: counter going backwards counts steps since the reset', () {
    final agg = StepAggregator();
    agg.ingest(8000, at(0));
    agg.ingest(8100, at(10));
    // Phone rebooted; sensor restarted from zero and already reads 35.
    final delta = agg.ingest(35, at(20))!;
    expect(delta.steps, 35);
    expect(delta.counterReset, isTrue);
    // New baseline is the post-reboot value, so growth continues normally.
    expect(agg.ingest(60, at(25))!.steps, 25);
  });

  test('a reboot never produces negative or inflated steps', () {
    final agg = StepAggregator();
    agg.ingest(1000000, at(0));
    final delta = agg.ingest(0, at(5));
    expect(delta, isNull); // reset to exactly 0: nothing to credit
    expect(agg.ingest(10, at(6))!.steps, 10);
  });

  test('negative or corrupt readings are ignored', () {
    final agg = StepAggregator();
    agg.ingest(100, at(0));
    expect(agg.ingest(-5, at(1)), isNull);
    expect(agg.lastCounter, 100);
    expect(agg.ingest(110, at(2))!.steps, 10);
  });

  test('persisted baseline survives an app restart', () {
    final first = StepAggregator();
    first.ingest(2000, at(0));
    final resumed = StepAggregator(
      lastCounter: first.lastCounter,
      lastReadingAt: first.lastReadingAt,
    );
    expect(resumed.ingest(2300, at(30))!.steps, 300);
  });

  group('gaps while the app was not receiving readings', () {
    test('same-day gap within the catch-up window is credited', () {
      final agg = StepAggregator();
      agg.ingest(1000, DateTime(2026, 3, 10, 8));
      final d = agg.ingest(4000, DateTime(2026, 3, 10, 15))!; // 7 h
      expect(d.steps, 3000);
      expect(d.discarded, 0);
    });

    test('gap longer than the window is discarded, not credited', () {
      final agg = StepAggregator(maxCatchUpGap: const Duration(hours: 6));
      agg.ingest(1000, DateTime(2026, 3, 10, 7));
      final d = agg.ingest(9000, DateTime(2026, 3, 10, 21))!; // 14 h
      expect(d.steps, 0);
      expect(d.discarded, 8000);
      // Baseline still moves forward so the next delta is clean.
      expect(agg.ingest(9050, DateTime(2026, 3, 10, 21, 5))!.steps, 50);
    });

    test('steps accumulated across midnight are not added to today', () {
      final agg = StepAggregator();
      agg.ingest(1000, DateTime(2026, 3, 10, 23, 50));
      final d = agg.ingest(1400, DateTime(2026, 3, 11, 0, 10))!;
      expect(d.steps, 0);
      expect(d.discarded, 400);
    });
  });
}
