import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/services/notification_service.dart';
import 'package:omnilife/presentation/widgets/notifications/notification_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationService notifService;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    notifService = NotificationService();
    Get.put(notifService);
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('NotificationSheet renders Rubric D2 banner and demo triggers',
      (tester) async {
    await notifService.init();

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: NotificationSheet(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications & Alerts'), findsOneWidget);
    expect(find.text('RUBRIC D2'), findsOneWidget);
    expect(find.text('Live Evaluation Demo Controls'), findsOneWidget);
    expect(find.byKey(const Key('demo_booking_notif_btn')), findsOneWidget);
    expect(find.byKey(const Key('demo_reminder_notif_btn')), findsOneWidget);
    expect(find.text('No notifications yet\nBooking confirmations and scheduled task reminders will appear here.'), findsOneWidget);
  });

  testWidgets('Tapping Test Booking triggers notification and updates list',
      (tester) async {
    await notifService.init();

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: NotificationSheet(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bookingBtn = find.byKey(const Key('demo_booking_notif_btn'));
    await tester.tap(bookingBtn);
    await tester.pumpAndSettle();

    expect(notifService.recentNotifications.length, 1);
    expect(find.text('Booking Confirmed: Project Viva Evaluation'), findsOneWidget);
  });

  testWidgets('Tapping Test Reminder triggers reminder notification and updates list',
      (tester) async {
    await notifService.init();

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: NotificationSheet(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reminderBtn = find.byKey(const Key('demo_reminder_notif_btn'));
    await tester.tap(reminderBtn);
    await tester.pumpAndSettle();

    expect(notifService.recentNotifications.length, 1);
    expect(find.text('Task Reminder: Submit MAD Course Portfolio'), findsOneWidget);
  });
}
