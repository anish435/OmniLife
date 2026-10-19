import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/errors/failures.dart';
import 'package:omnilife/core/services/notification_service.dart';
import 'package:omnilife/core/services/reminder_scheduler.dart';
import 'package:omnilife/core/utils/reminder_text.dart';
import 'package:omnilife/domain/entities/reminder.dart';
import 'package:omnilife/domain/repositories/reminder_repository.dart';
import 'package:omnilife/domain/usecases/reminders/reminder_service_impl.dart';

class FakeReminderRepository implements ReminderRepository {
  final items = <String, Reminder>{};

  @override
  Future<Reminder> create(Reminder r) async => items[r.id] = r;

  @override
  Future<Reminder> update(Reminder r) async => items[r.id] = r;

  @override
  Future<void> delete(Reminder r) async => items.remove(r.id);

  @override
  Future<List<Reminder>> list(String userId) async =>
      items.values.where((r) => r.userId == userId).toList();
}

class FakeScheduler implements ReminderScheduler {
  final scheduled = <Reminder>[];
  final cancelled = <String>[];

  @override
  Future<void> schedule(Reminder r) async => scheduled.add(r);

  @override
  Future<void> cancel(String id) async => cancelled.add(id);
}

class RecordingNotifications extends NotificationService {
  final calls = <Map<String, Object?>>[];
  final cancelledIds = <int>[];

  @override
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    ReminderRepeat repeat = ReminderRepeat.none,
    String? payload,
  }) async {
    calls.add({
      'id': id,
      'title': title,
      'body': body,
      'when': when,
      'repeat': repeat,
      'payload': payload,
    });
  }

  @override
  Future<void> cancelReminder(int id) async => cancelledIds.add(id);
}

void main() {
  final clock = DateTime(2026, 3, 4, 12);
  late FakeReminderRepository repo;
  late FakeScheduler scheduler;
  late ReminderServiceImpl service;
  String? uid = 'u1';
  var n = 0;

  setUp(() {
    repo = FakeReminderRepository();
    scheduler = FakeScheduler();
    uid = 'u1';
    n = 0;
    service = ReminderServiceImpl(
      repository: repo,
      scheduler: scheduler,
      uidProvider: () => uid,
      now: () => clock,
      newId: () => 'r${++n}',
    );
  });

  group('ReminderServiceImpl', () {
    test('create saves and schedules', () async {
      final r = await service.create(
        title: '  Call mum ',
        at: DateTime(2026, 3, 4, 18),
      );
      expect(r.title, 'Call mum');
      expect(r.userId, 'u1');
      expect(repo.items['r1'], r);
      expect(scheduler.scheduled.single, r);
    });

    test('create needs a signed-in user', () async {
      uid = null;
      expect(
        () => service.create(title: 'x', at: DateTime(2026, 3, 5)),
        throwsA(isA<AuthFailure>()),
      );
      expect(repo.items, isEmpty);
    });

    test('update reschedules and remove cancels', () async {
      final r = await service.create(title: 'a', at: DateTime(2026, 3, 5, 9));
      await service.update(r.copyWith(enabled: false));
      expect(scheduler.scheduled.last.enabled, isFalse);

      await service.remove(r);
      expect(repo.items, isEmpty);
      expect(scheduler.cancelled, ['r1']);
    });

    test('rescheduleAll registers every saved reminder for the user', () async {
      await service.create(title: 'a', at: DateTime(2026, 3, 5, 9));
      await service.create(
        title: 'b',
        at: DateTime(2026, 3, 5, 10),
        repeat: ReminderRepeat.daily,
      );
      scheduler.scheduled.clear();
      await service.rescheduleAll('u1');
      expect(scheduler.scheduled.map((r) => r.id), ['r1', 'r2']);
      expect(await service.all(), hasLength(2));
    });
  });

  group('NotificationReminderScheduler', () {
    late RecordingNotifications notifications;
    late NotificationReminderScheduler scheduler;

    Reminder reminder(ReminderRepeat repeat, {bool enabled = true}) => Reminder(
      id: 'abc',
      userId: 'u1',
      title: 'Stretch',
      scheduledAt: DateTime(2026, 3, 4, 20),
      repeat: repeat,
      enabled: enabled,
      createdAt: clock,
      updatedAt: clock,
    );

    setUp(() {
      notifications = RecordingNotifications();
      scheduler = NotificationReminderScheduler(
        notifications: () => notifications,
        now: () => clock,
      );
    });

    test('passes the repeat kind through for once, daily and weekly', () async {
      for (final repeat in ReminderRepeat.values) {
        await scheduler.schedule(reminder(repeat));
      }
      expect(
        notifications.calls.map((c) => c['repeat']),
        ReminderRepeat.values,
      );
      expect(
        notifications.calls.every((c) => c['when'] == DateTime(2026, 3, 4, 20)),
        isTrue,
      );
      expect(notifications.calls.first['payload'], 'reminder:abc');
      expect(notifications.calls.first['body'], 'Today, 8:00 PM');
    });

    test('uses the same stable id every time', () async {
      await scheduler.schedule(reminder(ReminderRepeat.none));
      await scheduler.schedule(reminder(ReminderRepeat.daily));
      final id = notifications.calls.first['id'] as int;
      expect(notifications.calls.last['id'], id);
      expect(id, reminderNotificationId('abc'));
      expect(id, greaterThanOrEqualTo(0));
      expect(reminderNotificationId('abd'), isNot(id));
    });

    test('disabled reminders are cancelled, not scheduled', () async {
      await scheduler.schedule(reminder(ReminderRepeat.daily, enabled: false));
      expect(notifications.calls, isEmpty);
      expect(notifications.cancelledIds, [reminderNotificationId('abc')]);
    });
  });

  group('InAppReminderScheduler (web)', () {
    test('fires a due one-off once, then stops', () async {
      var now = DateTime(2026, 3, 4, 12);
      final fired = <String>[];
      final s = InAppReminderScheduler(
        onDue: (r) => fired.add(r.id),
        now: () => now,
      );
      addTearDown(s.dispose);
      await s.schedule(
        Reminder(
          id: 'w1',
          userId: 'u1',
          title: 'Tea',
          scheduledAt: DateTime(2026, 3, 4, 12, 5),
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(s.isArmed, isTrue);

      now = DateTime(2026, 3, 4, 12, 4);
      s.tick();
      expect(fired, isEmpty);

      now = DateTime(2026, 3, 4, 12, 6);
      s.tick();
      s.tick();
      expect(fired, ['w1']);
      expect(s.isArmed, isFalse);
    });

    test('daily reminders keep firing each day', () async {
      var now = DateTime(2026, 3, 4, 12);
      final fired = <String>[];
      final s = InAppReminderScheduler(
        onDue: (r) => fired.add(r.id),
        now: () => now,
      );
      addTearDown(s.dispose);
      await s.schedule(
        Reminder(
          id: 'w2',
          userId: 'u1',
          title: 'Stretch',
          scheduledAt: DateTime(2026, 3, 1, 8),
          repeat: ReminderRepeat.daily,
          createdAt: now,
          updatedAt: now,
        ),
      );
      now = DateTime(2026, 3, 5, 8, 1);
      s.tick();
      now = DateTime(2026, 3, 6, 8, 1);
      s.tick();
      expect(fired, ['w2', 'w2']);
      expect(s.isArmed, isTrue);
    });
  });

  group('describeReminderWhen', () {
    Reminder r(DateTime at, [ReminderRepeat rep = ReminderRepeat.none]) =>
        Reminder(
          id: 'x',
          userId: 'u',
          title: 't',
          scheduledAt: at,
          repeat: rep,
          createdAt: clock,
          updatedAt: clock,
        );

    test('speaks plainly', () {
      expect(
        describeReminderWhen(r(DateTime(2026, 3, 4, 21)), clock),
        'Today, 9:00 PM',
      );
      expect(
        describeReminderWhen(r(DateTime(2026, 3, 5, 9)), clock),
        'Tomorrow, 9:00 AM',
      );
      expect(
        describeReminderWhen(
          r(DateTime(2026, 3, 1, 8), ReminderRepeat.daily),
          clock,
        ),
        'Every day at 8:00 AM',
      );
      expect(
        describeReminderWhen(
          r(DateTime(2026, 3, 2, 8), ReminderRepeat.weekly),
          clock,
        ),
        'Every Monday at 8:00 AM',
      );
      expect(
        describeReminderWhen(r(DateTime(2026, 3, 12, 8)), clock),
        'Thu, Mar 12, 8:00 AM',
      );
    });
  });
}
