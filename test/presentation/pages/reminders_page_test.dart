import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/reminder.dart';
import 'package:omnilife/domain/usecases/reminders/reminder_service_impl.dart';
import 'package:omnilife/presentation/controllers/reminders_controller.dart';
import 'package:omnilife/presentation/pages/reminders/reminders_page.dart';

import '../../domain/usecases/reminder_service_test.dart'
    show FakeReminderRepository, FakeScheduler;

void main() {
  final clock = DateTime(2026, 3, 4, 12);
  late FakeReminderRepository repo;
  late FakeScheduler scheduler;
  late RemindersController c;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repo = FakeReminderRepository();
    scheduler = FakeScheduler();
    c = RemindersController(
      service: ReminderServiceImpl(
        repository: repo,
        scheduler: scheduler,
        uidProvider: () => 'u1',
        now: () => clock,
        newId: () => 'new${repo.items.length + 1}',
      ),
      uidProvider: () => 'u1',
      now: () => clock,
    );
    Get.put<RemindersController>(c);
  });

  tearDown(Get.reset);

  Reminder make(
    String id,
    String title,
    DateTime at, [
    ReminderRepeat repeat = ReminderRepeat.none,
  ]) => Reminder(
    id: id,
    userId: 'u1',
    title: title,
    scheduledAt: at,
    repeat: repeat,
    createdAt: clock,
    updatedAt: clock,
  );

  Future<void> pump(WidgetTester tester, {double width = 375}) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const RemindersPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state uses friendly words', (tester) async {
    await pump(tester);
    expect(find.textContaining('Nothing to remember yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists groups with plain-language times at 375px', (
    tester,
  ) async {
    repo.items['a'] = make('a', 'Pay rent', DateTime(2026, 3, 4, 21));
    repo.items['b'] = make(
      'b',
      'Take vitamins with a really long title that needs to wrap nicely',
      DateTime(2026, 3, 1, 8),
      ReminderRepeat.daily,
    );
    repo.items['c'] = make('c', 'Old errand', DateTime(2026, 3, 3, 8));
    await c.load();
    await pump(tester);

    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('REPEATING'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('Today, 9:00 PM'), findsOneWidget);
    expect(find.text('Every day at 8:00 AM'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning the switch off updates the reminder', (tester) async {
    repo.items['a'] = make('a', 'Pay rent', DateTime(2026, 3, 4, 21));
    await c.load();
    await pump(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(repo.items['a']!.enabled, isFalse);
    expect(find.textContaining('Off'), findsOneWidget);
  });

  testWidgets('swipe deletes and Undo restores', (tester) async {
    repo.items['a'] = make('a', 'Pay rent', DateTime(2026, 3, 4, 21));
    await c.load();
    await pump(tester);

    await tester.drag(find.text('Pay rent'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(repo.items, isEmpty);
    expect(find.text('Reminder deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.items['a'], isNotNull);
    expect(find.text('Pay rent'), findsOneWidget);
  });

  testWidgets('menu delete works too', (tester) async {
    repo.items['a'] = make('a', 'Pay rent', DateTime(2026, 3, 4, 21));
    await c.load();
    await pump(tester);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.items, isEmpty);
  });

  testWidgets('new reminder sheet saves a reminder without overflow', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('New reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Once'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('Every week'), findsOneWidget);

    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Give your reminder a name.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Book dentist');
    await tester.tap(find.text('Every day'));
    await tester.pump();
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(repo.items.values.single.title, 'Book dentist');
    expect(repo.items.values.single.repeat, ReminderRepeat.daily);
    expect(scheduler.scheduled, hasLength(1));
    expect(find.text('Book dentist'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
