import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/focus/focus_timer.dart';

import '../../support/focus_push_fakes.dart';

void main() {
  late FakeClock clock;
  late List<FocusCompletion> completions;
  late FocusTimer timer;

  setUp(() {
    clock = FakeClock(DateTime(2026, 10, 6, 9));
    completions = [];
    timer = FocusTimer(clock: clock.call, onSessionCompleted: completions.add);
  });

  tearDown(() => timer.dispose());

  test('defaults to idle with 25 minute focus and 5 minute break', () {
    expect(timer.phase, FocusPhase.idle);
    expect(timer.state.focusDuration, const Duration(minutes: 25));
    expect(timer.state.breakDuration, const Duration(minutes: 5));
    expect(timer.remaining, const Duration(minutes: 25));
  });

  test('start runs and remaining is computed from the clock, not ticks', () {
    expect(timer.start(), isTrue);
    expect(timer.phase, FocusPhase.running);

    clock.advance(const Duration(minutes: 10, seconds: 30));
    // No tick() call at all: remaining still reflects elapsed time.
    expect(timer.remaining, const Duration(minutes: 14, seconds: 30));
    expect(timer.progress, closeTo(630 / 1500, 0.0001));
  });

  test('start is ignored while a session is active', () {
    timer.start();
    expect(timer.start(), isFalse);
  });

  test('pause freezes remaining and resume excludes the paused time', () {
    timer.start();
    clock.advance(const Duration(minutes: 5));
    expect(timer.pause(), isTrue);
    expect(timer.phase, FocusPhase.paused);

    clock.advance(const Duration(minutes: 20));
    expect(timer.remaining, const Duration(minutes: 20));

    expect(timer.resume(), isTrue);
    expect(timer.phase, FocusPhase.running);
    clock.advance(const Duration(minutes: 5));
    expect(timer.remaining, const Duration(minutes: 15));
  });

  test('completion fires once at the true end time, including pauses', () {
    timer.start();
    final start = clock.now;
    clock.advance(const Duration(minutes: 10));
    timer.pause();
    clock.advance(const Duration(minutes: 7));
    timer.resume();
    clock.advance(const Duration(minutes: 15));
    timer.tick();

    expect(timer.phase, FocusPhase.completed);
    expect(completions, hasLength(1));
    expect(completions.single.startedAt, start);
    expect(
      completions.single.endedAt,
      start.add(const Duration(minutes: 7 + 25)),
    );
    expect(completions.single.focusedDuration, const Duration(minutes: 25));

    clock.advance(const Duration(minutes: 3));
    timer.tick();
    timer.tick();
    expect(completions, hasLength(1));
  });

  test('tick before the end does not complete', () {
    timer.start();
    clock.advance(const Duration(minutes: 24, seconds: 59));
    timer.tick();
    expect(timer.phase, FocusPhase.running);
    expect(completions, isEmpty);
  });

  test('completed -> startBreak -> break ends back to idle without event', () {
    timer.start();
    clock.advance(const Duration(minutes: 25));
    timer.tick();
    expect(timer.startBreak(), isTrue);
    expect(timer.phase, FocusPhase.onBreak);
    expect(timer.remaining, const Duration(minutes: 5));

    clock.advance(const Duration(minutes: 5));
    timer.tick();
    expect(timer.phase, FocusPhase.idle);
    expect(completions, hasLength(1));
  });

  test('skipBreak returns to idle from completed and from a running break', () {
    timer.start();
    clock.advance(const Duration(minutes: 25));
    timer.tick();
    expect(timer.skipBreak(), isTrue);
    expect(timer.phase, FocusPhase.idle);

    timer.start();
    clock.advance(const Duration(minutes: 25));
    timer.tick();
    timer.startBreak();
    clock.advance(const Duration(minutes: 1));
    expect(timer.skipBreak(), isTrue);
    expect(timer.phase, FocusPhase.idle);
  });

  test('skipBreak is ignored while focusing', () {
    timer.start();
    expect(timer.skipBreak(), isFalse);
    expect(timer.phase, FocusPhase.running);
  });

  test('a break can be paused and resumed', () {
    timer.start();
    clock.advance(const Duration(minutes: 25));
    timer.tick();
    timer.startBreak();
    clock.advance(const Duration(minutes: 2));
    timer.pause();
    expect(timer.state.segment, FocusSegment.rest);
    clock.advance(const Duration(minutes: 30));
    timer.resume();
    expect(timer.phase, FocusPhase.onBreak);
    expect(timer.remaining, const Duration(minutes: 3));
  });

  test('stop discards the session without recording', () {
    timer.start();
    clock.advance(const Duration(minutes: 3));
    timer.stop();
    expect(timer.phase, FocusPhase.idle);
    clock.advance(const Duration(hours: 1));
    timer.tick();
    expect(completions, isEmpty);
  });

  test('configure changes lengths only when not active', () {
    expect(timer.configure(focus: const Duration(minutes: 50)), isTrue);
    expect(timer.remaining, const Duration(minutes: 50));
    timer.start();
    expect(timer.configure(focus: const Duration(minutes: 10)), isFalse);
    expect(timer.state.focusDuration, const Duration(minutes: 50));
    timer.stop();
    expect(timer.configure(focus: Duration.zero), isFalse);
  });

  group('restart recovery', () {
    test('snapshot survives JSON round trip and keeps remaining time', () {
      timer.start();
      clock.advance(const Duration(minutes: 4));
      timer.pause();
      clock.advance(const Duration(minutes: 2));
      timer.resume();
      clock.advance(const Duration(minutes: 1));

      final json = timer.state.toJson();
      final restored = FocusTimerState.fromJson(json);

      // "App restart" 6 more minutes later, using a fresh timer.
      clock.advance(const Duration(minutes: 6));
      final fresh = FocusTimer(
        clock: clock.call,
        onSessionCompleted: completions.add,
      )..restore(restored);

      expect(fresh.phase, FocusPhase.running);
      // 4 + 1 + 6 = 11 minutes of focus elapsed.
      expect(fresh.remaining, const Duration(minutes: 14));
      fresh.dispose();
    });

    test('a segment that ended while the app was closed completes at once', () {
      timer.start();
      final start = clock.now;
      final snapshot = FocusTimerState.fromJson(timer.state.toJson());

      clock.advance(const Duration(hours: 2));
      final fresh = FocusTimer(
        clock: clock.call,
        onSessionCompleted: completions.add,
      )..restore(snapshot);

      expect(fresh.phase, FocusPhase.completed);
      expect(completions, hasLength(1));
      expect(
        completions.single.endedAt,
        start.add(const Duration(minutes: 25)),
      );
      fresh.dispose();
    });

    test('restoring an already completed snapshot does not fire again', () {
      timer.start();
      clock.advance(const Duration(minutes: 25));
      timer.tick();
      final snapshot = FocusTimerState.fromJson(timer.state.toJson());
      completions.clear();

      final fresh = FocusTimer(
        clock: clock.call,
        onSessionCompleted: completions.add,
      )..restore(snapshot);
      expect(fresh.phase, FocusPhase.completed);
      expect(completions, isEmpty);
      fresh.dispose();
    });

    test('a paused snapshot stays paused after restart', () {
      timer.start();
      clock.advance(const Duration(minutes: 5));
      timer.pause();
      final snapshot = FocusTimerState.fromJson(timer.state.toJson());

      clock.advance(const Duration(days: 1));
      final fresh = FocusTimer(clock: clock.call)..restore(snapshot);
      expect(fresh.phase, FocusPhase.paused);
      expect(fresh.remaining, const Duration(minutes: 20));
      fresh.dispose();
    });
  });

  test('injected ticker drives completion and stops when idle', () async {
    final ticks = <void>[];
    var subscribed = 0;
    var cancelled = 0;
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onListen: () => subscribed++,
      onCancel: () => cancelled++,
      sync: true,
    );
    final ticked = FocusTimer(
      clock: clock.call,
      ticker: () => controller.stream,
      focusDuration: const Duration(minutes: 1),
      onSessionCompleted: completions.add,
    );
    ticked.stream.listen(ticks.add);

    ticked.start();
    expect(subscribed, 1);
    clock.advance(const Duration(seconds: 30));
    controller.add(null);
    expect(ticked.phase, FocusPhase.running);

    clock.advance(const Duration(seconds: 30));
    controller.add(null);
    expect(ticked.phase, FocusPhase.completed);
    expect(completions, hasLength(1));
    expect(cancelled, 1);
    ticked.dispose();
    await controller.close();
  });
}
