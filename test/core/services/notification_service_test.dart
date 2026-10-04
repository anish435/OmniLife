import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/services/notification_service.dart';
import 'package:omnilife/domain/entities/app_notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationService service;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    service = NotificationService();
    Get.put(service);
  });

  tearDown(() {
    Get.reset();
  });

  group('NotificationService (Rubric D2)', () {
    test('initializes cleanly without errors', () async {
      await service.init();
      expect(service.isInitialized.value, isTrue);
      expect(service.recentNotifications, isEmpty);
      expect(service.unreadCount, 0);
    });

    test('showBookingConfirmation inserts notification and increments unreadCount', () async {
      await service.init();
      final eventTime = DateTime(2026, 10, 10, 15, 30);

      await service.showBookingConfirmation(
        title: 'Project Viva Demo',
        startAt: eventTime,
        location: 'Hall B',
        eventId: 'event_123',
      );

      expect(service.recentNotifications.length, 1);
      final item = service.recentNotifications.first;
      expect(item.title, 'Booking Confirmed: Project Viva Demo');
      expect(item.body, contains('Hall B'));
      expect(item.type, NotificationType.bookingConfirmed);
      expect(item.isRead, isFalse);
      expect(service.unreadCount, 1);
    });

    test('showTaskReminder inserts task reminder notification', () async {
      await service.init();
      final due = DateTime(2026, 10, 10, 18, 0);

      await service.showTaskReminder(
        title: 'Submit Lab Report',
        dueDate: due,
        taskId: 'task_456',
      );

      expect(service.recentNotifications.length, 1);
      final item = service.recentNotifications.first;
      expect(item.title, 'Task Reminder: Submit Lab Report');
      expect(item.type, NotificationType.taskReminder);
      expect(item.payload, 'task_456');
    });

    test('showDemoNotification creates pre-configured demo alert', () async {
      await service.init();

      await service.showDemoNotification(isBooking: true);
      expect(service.recentNotifications.length, 1);
      expect(service.recentNotifications.first.title, contains('Viva'));

      await service.showDemoNotification(isBooking: false);
      expect(service.recentNotifications.length, 2);
      expect(service.recentNotifications.first.title, contains('Course Portfolio'));
    });

    test('markAllAsRead and clearAll update reactive state correctly', () async {
      await service.init();

      await service.showDemoNotification(isBooking: true);
      await service.showDemoNotification(isBooking: false);
      expect(service.unreadCount, 2);

      service.markAllAsRead();
      expect(service.unreadCount, 0);
      expect(service.recentNotifications.every((n) => n.isRead), isTrue);

      service.clearAll();
      expect(service.recentNotifications, isEmpty);
    });
  });
}
