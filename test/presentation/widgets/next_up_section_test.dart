import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/data/insights/prefs_next_up_store.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/insights/next_up.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_insights_service.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';
import 'package:omnilife/presentation/controllers/next_up_controller.dart';
import 'package:omnilife/presentation/controllers/pulse_controller.dart';
import 'package:omnilife/presentation/widgets/next_up/next_up_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/assistant_fakes.dart';

void main() {
  late AssistantHarness h;
  late PulseController pulse;

  tearDown(Get.reset);

  /// A harness whose clock is [now], with a Pulse controller that can load
  /// today's events.
  Future<NextUpController> setup({
    DateTime? now,
    NextUpStore? store,
    bool task = true,
  }) async {
    h = await AssistantHarness.create(
      script: (_) => const AiResponse(),
      now: now ?? DateTime(2026, 10, 19, 14, 5),
    );
    final clock = h.now;
    pulse = PulseController(
      service: PulseService(events: h.lifeEvents, now: () => clock),
      insights: PulseInsightsService(
        events: h.lifeEvents,
        tasks: h.taskRepo,
        habits: h.habitRepo,
        now: () => clock,
      ),
      events: h.lifeEvents,
      uidProvider: () => 'u1',
      now: () => clock,
    );
    Get.put<PulseController>(pulse);
    if (task) {
      await h.tasks.createTask(title: 'Pay rent', dueDate: clock);
    }
    await pulse.loadDay(clock);
    return NextUpController(
      store: store ?? InMemoryNextUpStore(),
      uidProvider: () => 'u1',
      now: () => clock,
      tasks: () => h.tasks,
      habits: () => h.habits,
      reminders: () => null,
      pulse: () => pulse,
    );
  }

  Future<NextUpController> make(
    WidgetTester tester, {
    DateTime? now,
    NextUpStore? store,
    bool task = true,
  }) async =>
      (await tester.runAsync(() => setup(now: now, store: store, task: task)))!;

  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> pumpSection(
    WidgetTester tester,
    NextUpController c, {
    double width = 375,
  }) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(children: [NextUpSection(controller: c)]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows short, human lines at 375px without overflow', (
    tester,
  ) async {
    final c = await make(tester);
    await pumpSection(tester, c);

    expect(tester.takeException(), isNull);
    expect(find.text('NEXT UP'), findsOneWidget);
    expect(find.text('1 task due today'), findsOneWidget);
    expect(find.text('No water logged yet today'), findsOneWidget);
    expect(find.text('No meal logged yet today'), findsOneWidget);
    expect(find.text('Log water'), findsOneWidget);
  });

  testWidgets('still fits a narrow phone', (tester) async {
    final c = await make(tester);
    await pumpSection(tester, c, width: 320);
    expect(tester.takeException(), isNull);
    expect(find.text('1 task due today'), findsOneWidget);
  });

  testWidgets('hides itself when there is nothing useful to say', (
    tester,
  ) async {
    final c = await make(
      tester,
      now: DateTime(2026, 10, 19, 23, 30),
      task: false,
    );
    await pumpSection(tester, c);
    expect(find.text('NEXT UP'), findsNothing);
  });

  testWidgets('dismissing hides a hint now and for the rest of the day', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsNextUpStore();
    final c = await make(tester, store: store);
    await pumpSection(tester, c);

    expect(find.text('No meal logged yet today'), findsOneWidget);
    // Dismiss the meal row (the last of three).
    await tester.tap(find.byTooltip('Hide for today').last);
    await settleIo(tester);
    expect(find.text('No meal logged yet today'), findsNothing);
    expect(find.text('1 task due today'), findsOneWidget);

    // A fresh controller (a new app launch) remembers.
    final again = NextUpController(
      store: PrefsNextUpStore(),
      uidProvider: () => 'u1',
      now: () => h.now,
      tasks: () => h.tasks,
      habits: () => h.habits,
      reminders: () => null,
      pulse: () => pulse,
    );
    await tester.pumpWidget(const SizedBox());
    await pumpSection(tester, again);
    await settleIo(tester);
    expect(find.text('No meal logged yet today'), findsNothing);
    expect(find.text('No water logged yet today'), findsOneWidget);

    // Tomorrow it is allowed back.
    final tomorrow = NextUpController(
      store: PrefsNextUpStore(),
      uidProvider: () => 'u1',
      now: () => h.now.add(const Duration(days: 1)),
      tasks: () => null,
      habits: () => null,
      reminders: () => null,
      pulse: () => null,
    );
    await tester.runAsync(tomorrow.ensureLoaded);
    expect(tomorrow.suppressed, isEmpty);
  });

  testWidgets('one tap logs water, confirms with Undo, and hides the hint', (
    tester,
  ) async {
    final c = await make(tester);
    await pumpSection(tester, c);

    await tester.tap(find.text('Log water'));
    await settleIo(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      h.lifeEvents.events.values.where((e) => e.type == LifeEventType.water),
      hasLength(1),
    );
    expect(find.text('Water logged'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('No water logged yet today'), findsNothing);
    // Never the same hint twice in a day.
    expect(c.suppressed, contains('water'));
  });

  testWidgets('refreshes when events change', (tester) async {
    final c = await make(tester);
    await pumpSection(tester, c);
    expect(find.text('No meal logged yet today'), findsOneWidget);

    await tester.runAsync(() => pulse.log(LifeEventType.meal));
    await tester.pump();
    expect(find.text('No meal logged yet today'), findsNothing);
  });
}
