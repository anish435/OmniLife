import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/notification_actions.dart';

void main() {
  late List<String> completed;
  late List<(int, String?, DateTime)> snoozed;
  late DateTime now;
  late NotificationActionHandler handler;

  setUp(() {
    completed = [];
    snoozed = [];
    now = DateTime(2026, 10, 6, 12);
    handler = NotificationActionHandler(
      completeTask: (id) async => completed.add(id),
      scheduleSnooze: (id, payload, when) async =>
          snoozed.add((id, payload, when)),
      clock: () => now,
    );
  });

  test('Mark done completes the task named in the payload', () async {
    final outcome = await handler.handle(
      actionId: NotificationActionIds.markDone,
      payload: 'task:t1',
      notificationId: 5,
    );
    expect(outcome, NotificationActionOutcome.completed);
    expect(completed, ['t1']);
  });

  test('Mark done on a non-task payload does nothing', () async {
    final outcome = await handler.handle(
      actionId: NotificationActionIds.markDone,
      payload: 'calendar:e1',
      notificationId: 5,
    );
    expect(outcome, NotificationActionOutcome.none);
    expect(completed, isEmpty);
  });

  test('Snooze reschedules 10 minutes later with the same payload', () async {
    final outcome = await handler.handle(
      actionId: NotificationActionIds.snooze,
      payload: 'task:t1',
      notificationId: 77,
    );
    expect(outcome, NotificationActionOutcome.snoozed);
    expect(snoozed, [(77, 'task:t1', now.add(const Duration(minutes: 10)))]);
  });

  test('unknown action ids are ignored', () async {
    final outcome = await handler.handle(
      actionId: 'other',
      payload: 'task:t1',
      notificationId: 1,
    );
    expect(outcome, NotificationActionOutcome.none);
    expect(completed, isEmpty);
    expect(snoozed, isEmpty);
  });

  test('failures are reported, not thrown', () async {
    final failing = NotificationActionHandler(
      completeTask: (_) async => throw StateError('db closed'),
      scheduleSnooze: (a, b, c) async {},
    );
    final outcome = await failing.handle(
      actionId: NotificationActionIds.markDone,
      payload: 'task:t1',
      notificationId: 1,
    );
    expect(outcome, NotificationActionOutcome.failed);
  });
}
