import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/core/services/sensors/sensor_service.dart';
import 'package:omnilife/data/datasources/local/steps_local_store.dart';
import 'package:omnilife/data/repositories/steps_repository_impl.dart';
import 'package:omnilife/presentation/controllers/sensors_controller.dart';
import 'package:omnilife/presentation/pages/sensors/sensors_page.dart';
import 'package:omnilife/presentation/widgets/sensors/steps_bar_chart.dart';
import 'package:omnilife/domain/entities/daily_steps.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  late FakeSensorService sensors;
  late StepsRepositoryImpl repo;
  late DateTime now;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    now = DateTime(2026, 3, 10, 9);
    sensors = FakeSensorService();
    repo = StepsRepositoryImpl(
      store: InMemoryStepsStore(),
      remote: FakeRemote(),
      userIdProvider: () => 'u1',
      clock: () => now,
      syncInterval: Duration.zero,
    );
  });

  tearDown(() async {
    Get.reset();
    await repo.dispose();
  });

  Future<void> pumpSensors(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Get.put(
      SensorsController(sensors: sensors, repository: repo, clock: () => now),
    );
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SensorsPage()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('unsupported platform explains instead of failing', (
    tester,
  ) async {
    sensors = FakeSensorService(supported: false);
    await pumpSensors(tester);

    expect(find.text('Step counting is not available here'), findsOneWidget);
    expect(
      find.text('Face-down detection is not available here'),
      findsOneWidget,
    );
    expect(find.text('Turn on step tracking'), findsNothing);
    expect(sensors.requestCount, 0);
  });

  testWidgets('shows the turn-on prompt and requests only after the tap', (
    tester,
  ) async {
    sensors.accessAfterRequest = SensorAccess.granted;
    await pumpSensors(tester);

    expect(sensors.requestCount, 0);
    expect(find.text('Count your steps'), findsOneWidget);

    await tester.tap(find.text('Turn on step tracking'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(sensors.requestCount, 1);
    expect(find.textContaining('Tracking is on'), findsOneWidget);

    sensors.emitSteps(100);
    now = DateTime(2026, 3, 10, 9, 5);
    sensors.emitSteps(342);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.widget<Text>(find.byKey(const Key('today_steps_value'))).data,
      '242',
    );
  });

  testWidgets('permanently denied offers Open settings', (tester) async {
    sensors.access = SensorAccess.deniedForever;
    await pumpSensors(tester);

    expect(find.text('Activity permission is blocked'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(sensors.settingsOpened, 1);
  });

  testWidgets('goal dialog sets the goal and shows progress', (tester) async {
    await pumpSensors(tester);

    await tester.tap(find.byKey(const Key('edit_goal_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('goal_field')), '8000');
    await tester.tap(find.byKey(const Key('goal_save_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('of 8000 steps'), findsOneWidget);
    expect(find.byKey(const Key('goal_progress')), findsOneWidget);
    expect(await repo.dailyGoal(), 8000);
  });

  testWidgets('flip switch starts sampling and leaving the page stops it', (
    tester,
  ) async {
    await pumpSensors(tester);
    expect(sensors.accelListeners, 0);

    await tester.tap(find.byKey(const Key('flip_switch')));
    await tester.pump();
    expect(sensors.accelListeners, 1);
    expect(find.textContaining('Listening'), findsOneWidget);

    sensors.emitAccel(
      AccelSample(x: 0, y: 0, z: -9.8, timestamp: DateTime(2026, 1, 1)),
    );
    sensors.emitAccel(
      AccelSample(
        x: 0,
        y: 0,
        z: -9.8,
        timestamp: DateTime(2026, 1, 1, 0, 0, 2),
      ),
    );
    await tester.pump();
    expect(find.text('Phone is face down'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(sensors.accelListeners, 0);
  });

  testWidgets('bar chart draws seven bars scaled to the maximum and goal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final days = [
      for (var i = 0; i < 7; i++)
        DailySteps(date: DateTime(2026, 3, 4 + i), steps: i * 1000),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StepsBarChart(days: days, goal: 10000)),
      ),
    );

    final bar6 = tester.getSize(find.byKey(const Key('steps_bar_6')));
    final bar3 = tester.getSize(find.byKey(const Key('steps_bar_3')));
    final bar0 = tester.getSize(find.byKey(const Key('steps_bar_0')));
    expect(bar6.height, closeTo(120 * 0.6, 0.5)); // 6000 of 10000 (goal)
    expect(bar3.height, closeTo(120 * 0.3, 0.5));
    expect(bar0.height, 2); // zero still visible as a stub
    expect(find.byKey(const Key('steps_goal_line')), findsOneWidget);
  });
}
