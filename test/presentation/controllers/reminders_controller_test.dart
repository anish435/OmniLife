import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/entities/reminder.dart';
import 'package:omnilife/domain/usecases/reminders/reminder_service_impl.dart';
import 'package:omnilife/presentation/controllers/reminders_controller.dart';

import '../../domain/usecases/reminder_service_test.dart'
    show FakeReminderRepository, FakeScheduler;

void main() {
  final clock = DateTime(2026, 3, 4, 12);
  late FakeReminderRepository repo;
  late FakeScheduler scheduler;
  late RemindersController c;
  var n = 0;

  setUp(() {
    Get.testMode = true;
    repo = FakeReminderRepository();
    scheduler = FakeScheduler();
    n = 0;
    c = RemindersController(
      service: ReminderServiceImpl(
        repository: repo,
        scheduler: scheduler,
        uidProvider: () => 'u1',
        now: () => clock,
        newId: () => 'r${++n}',
      ),
      uidProvider: () => 'u1',
      now: () => clock,
    );
  });

  test('save creates a reminder and groups it as upcoming', () async {
    final err = await c.save(
      title: 'Pay rent',
      at: DateTime(2026, 3, 4, 20),
      repeat: ReminderRepeat.none,
    );
    expect(err, isNull);
    expect(c.upcoming.single.title, 'Pay rent');
    expect(c.repeating, isEmpty);
    expect(scheduler.scheduled, hasLength(1));
  });

  test('groups upcoming, repeating and done', () async {
    await c.save(
      title: 'Later',
      at: DateTime(2026, 3, 6, 9),
      repeat: ReminderRepeat.none,
    );
    await c.save(
      title: 'Daily',
      at: DateTime(2026, 3, 5, 8),
      repeat: ReminderRepeat.daily,
    );
    final old = Reminder(
      id: 'old',
      userId: 'u1',
      title: 'Past one',
      scheduledAt: DateTime(2026, 3, 3, 8),
      createdAt: clock,
      updatedAt: clock,
    );
    repo.items['old'] = old;
    await c.load();

    expect(c.upcoming.map((r) => r.title), ['Later']);
    expect(c.repeating.map((r) => r.title), ['Daily']);
    expect(c.done.map((r) => r.title), ['Past one']);
  });

  test('rejects an empty title and a past one-off time', () async {
    expect(
      await c.save(
        title: '  ',
        at: DateTime(2026, 3, 5),
        repeat: ReminderRepeat.none,
      ),
      isNotNull,
    );
    expect(
      await c.save(
        title: 'x',
        at: DateTime(2026, 3, 1),
        repeat: ReminderRepeat.none,
      ),
      contains('passed'),
    );
    expect(repo.items, isEmpty);
  });

  test('toggle off reschedules (cancels) through the service', () async {
    await c.save(
      title: 'Daily',
      at: DateTime(2026, 3, 5, 8),
      repeat: ReminderRepeat.daily,
    );
    await c.setEnabled(c.reminders.single, false);
    expect(c.reminders.single.enabled, isFalse);
    expect(repo.items['r1']!.enabled, isFalse);
    expect(scheduler.scheduled.last.enabled, isFalse);
  });

  test('delete then undo brings the same reminder back', () async {
    await c.save(
      title: 'Call back',
      at: DateTime(2026, 3, 5, 9),
      repeat: ReminderRepeat.none,
    );
    final r = c.reminders.single;
    await c.delete(r);
    expect(c.reminders, isEmpty);
    expect(repo.items, isEmpty);
    expect(scheduler.cancelled, ['r1']);

    await c.undoDelete(r);
    expect(c.reminders.single.id, 'r1');
    expect(repo.items['r1'], isNotNull);
  });

  test('editing keeps the id and changes the time', () async {
    await c.save(
      title: 'Walk',
      at: DateTime(2026, 3, 5, 9),
      repeat: ReminderRepeat.none,
    );
    await c.save(
      existing: c.reminders.single,
      title: 'Long walk',
      at: DateTime(2026, 3, 5, 10),
      repeat: ReminderRepeat.weekly,
    );
    final r = c.reminders.single;
    expect(r.id, 'r1');
    expect(r.title, 'Long walk');
    expect(r.repeat, ReminderRepeat.weekly);
  });
}
