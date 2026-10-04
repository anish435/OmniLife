import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/app_notification.dart';

void main() {
  group('AppNotification Entity (Rubric D2)', () {
    final now = DateTime(2026, 10, 5, 14, 30);

    test('supports value equality', () {
      final notif1 = AppNotification(
        id: '1',
        title: 'Booking Confirmed',
        body: 'Scheduled for 2:30 PM',
        type: NotificationType.bookingConfirmed,
        timestamp: now,
      );

      final notif2 = AppNotification(
        id: '1',
        title: 'Booking Confirmed',
        body: 'Scheduled for 2:30 PM',
        type: NotificationType.bookingConfirmed,
        timestamp: now,
      );

      expect(notif1, equals(notif2));
    });

    test('copyWith overrides only specified fields', () {
      final notif = AppNotification(
        id: '1',
        title: 'Task Reminder',
        body: 'Due soon',
        type: NotificationType.taskReminder,
        timestamp: now,
        isRead: false,
      );

      final updated = notif.copyWith(isRead: true, title: 'Updated Reminder');

      expect(updated.id, '1');
      expect(updated.title, 'Updated Reminder');
      expect(updated.body, 'Due soon');
      expect(updated.type, NotificationType.taskReminder);
      expect(updated.isRead, isTrue);
    });

    test('supports all NotificationType values', () {
      expect(NotificationType.values.length, 4);
      expect(NotificationType.values, contains(NotificationType.bookingConfirmed));
      expect(NotificationType.values, contains(NotificationType.bookingReminder));
      expect(NotificationType.values, contains(NotificationType.taskReminder));
      expect(NotificationType.values, contains(NotificationType.system));
    });
  });
}
