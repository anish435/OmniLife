import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/focus/focus_state_store.dart';
import 'package:omnilife/presentation/controllers/focus_controller.dart';
import 'package:omnilife/presentation/pages/focus/focus_page.dart';

import '../../support/focus_push_fakes.dart';

void main() {
  late FakeClock clock;
  late FocusController controller;
  late FakeVideo video;
  late InMemoryFocusRepository repository;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clock = FakeClock(DateTime(2026, 10, 7, 9));
    repository = InMemoryFocusRepository();
    video = FakeVideo();
    controller = FocusController(
      repository: repository,
      stateStore: InMemoryFocusStateStore(),
      audio: FakeAmbientAudio(),
      video: video,
      eventSink: RecordingFocusSink(),
      userIdProvider: () => 'u1',
      clock: clock.call,
      ticker: null,
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const FocusPage()),
    );
    await tester.pump();
  }

  testWidgets('idle state shows the clock, lengths, and empty history', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Start focus'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No focus sessions yet today.\nStart one above.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('No focus sessions yet today.\nStart one above.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('start, pause and resume change the controls', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Start focus'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('FOCUS'), findsOneWidget);

    clock.advance(const Duration(minutes: 1, seconds: 5));
    controller.timer.tick();
    await tester.pump();
    expect(find.text('23:55'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('FOCUS PAUSED'), findsOneWidget);
  });

  testWidgets('selecting a different focus length updates the clock', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('45 min'));
    await tester.pump();
    expect(find.text('45:00'), findsOneWidget);
  });

  testWidgets('completing a session shows the break choice and history', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text('Start focus'));
    await tester.pump();

    clock.advance(const Duration(minutes: 25));
    controller.timer.tick();
    await tester.pump();
    await tester.pump();

    expect(find.text('SESSION COMPLETE'), findsOneWidget);
    expect(find.text('Start break'), findsOneWidget);
    expect(find.text('25 min focus'), findsOneWidget);
    expect(find.text('25m'), findsNWidgets(2)); // today and this week
  });

  testWidgets(
    'video panel shows an error for a bad address and a view for a good one',
    (tester) async {
      await pumpPage(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('focus_video_load')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.byKey(const Key('focus_video_load')));
      await tester.pump();
      expect(
        find.text('Enter a valid http or https video address.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/v.mp4',
      );
      await tester.tap(find.byKey(const Key('focus_video_load')));
      await tester.pump();
      expect(find.byKey(const Key('fake_video')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
