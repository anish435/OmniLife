import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/sensors/sensor_service.dart';
import 'package:omnilife/data/datasources/local/steps_local_store.dart';
import 'package:omnilife/data/repositories/steps_repository_impl.dart';
import 'package:omnilife/presentation/controllers/sensors_controller.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  late FakeSensorService sensors;
  late FakeRemote remote;
  late StepsRepositoryImpl repo;
  late SensorsController controller;
  late DateTime now;

  SensorsController build() =>
      SensorsController(sensors: sensors, repository: repo, clock: () => now);

  Future<void> start() async {
    controller.onInit();
    await pumpEventQueue();
  }

  AccelSample z(double v, int ms) => AccelSample(
    x: 0,
    y: 0,
    z: v,
    timestamp: DateTime(2026, 1, 1).add(Duration(milliseconds: ms)),
  );

  setUp(() {
    now = DateTime(2026, 3, 10, 9);
    sensors = FakeSensorService();
    remote = FakeRemote();
    repo = StepsRepositoryImpl(
      store: InMemoryStepsStore(),
      remote: remote,
      userIdProvider: () => 'u1',
      clock: () => now,
      syncInterval: Duration.zero,
    );
    controller = build();
  });

  tearDown(() async {
    controller.onClose();
    await repo.dispose();
  });

  group('step permission state machine', () {
    test('opening the screen never prompts and registers no sensor', () async {
      await start();

      expect(sensors.requestCount, 0);
      expect(sensors.stepListeners, 0);
      expect(sensors.accelListeners, 0);
      expect(controller.stepAccess.value, SensorAccess.denied);
      expect(controller.trackingEnabled.value, isFalse);
    });

    test('enable prompts, then counts steps from the pedometer', () async {
      sensors.accessAfterRequest = SensorAccess.granted;
      await start();

      await controller.enableTracking();

      expect(sensors.requestCount, 1);
      expect(controller.trackingEnabled.value, isTrue);
      expect(await repo.isTrackingEnabled(), isTrue);
      expect(sensors.stepListeners, 1);

      sensors.emitSteps(1000); // baseline
      now = DateTime(2026, 3, 10, 9, 10);
      sensors.emitSteps(1250);
      await pumpEventQueue();

      expect(controller.hasReading.value, isTrue);
      expect(controller.todaySteps.value, 250);
      expect(controller.week.last.steps, 250);
    });

    test('denied: stays off, explains, and can be retried', () async {
      sensors.accessAfterRequest = SensorAccess.denied;
      await start();

      await controller.enableTracking();

      expect(controller.trackingEnabled.value, isFalse);
      expect(sensors.stepListeners, 0);
      expect(controller.notice.value, contains('permission'));
      await controller.enableTracking();
      expect(sensors.requestCount, 2);
    });

    test('permanent denial routes to settings', () async {
      sensors.accessAfterRequest = SensorAccess.deniedForever;
      await start();
      await controller.enableTracking();

      expect(controller.stepAccess.value, SensorAccess.deniedForever);
      expect(controller.trackingEnabled.value, isFalse);

      await controller.openSettings();
      expect(sensors.settingsOpened, 1);
    });

    test(
      'resumes silently when previously enabled and still granted',
      () async {
        await repo.setTrackingEnabled(true);
        sensors.access = SensorAccess.granted;
        await start();

        expect(sensors.requestCount, 0); // no prompt on open
        expect(sensors.stepListeners, 1);
        expect(controller.trackingEnabled.value, isTrue);
      },
    );

    test('does not resume when the permission was revoked meanwhile', () async {
      await repo.setTrackingEnabled(true);
      sensors.access = SensorAccess.denied;
      await start();

      expect(sensors.stepListeners, 0);
      expect(controller.stepsGranted, isFalse);
    });

    test('turning tracking off releases the listener', () async {
      sensors.accessAfterRequest = SensorAccess.granted;
      await start();
      await controller.enableTracking();

      await controller.disableTracking();

      expect(sensors.stepListeners, 0);
      expect(await repo.isTrackingEnabled(), isFalse);
      expect(controller.hasReading.value, isFalse);
    });

    test('closing the screen releases every sensor', () async {
      sensors.accessAfterRequest = SensorAccess.granted;
      await start();
      await controller.enableTracking();
      controller.setFlipDetection(true);
      expect(sensors.stepListeners, 1);
      expect(sensors.accelListeners, 1);

      controller.onClose();
      await pumpEventQueue();

      expect(sensors.stepListeners, 0);
      expect(sensors.accelListeners, 0);
    });
  });

  group('unsupported platform (web / desktop)', () {
    setUp(() {
      sensors = FakeSensorService(supported: false);
      controller = build();
    });

    test('reports unsupported cleanly and never prompts', () async {
      await start();

      expect(controller.isSupported, isFalse);
      expect(controller.stepAccess.value, SensorAccess.unsupported);
      await controller.enableTracking();
      controller.setFlipDetection(true);

      expect(sensors.requestCount, 0);
      expect(sensors.stepListeners, 0);
      expect(sensors.accelListeners, 0);
      expect(controller.flipActive.value, isFalse);
    });

    test('still shows previously stored history', () async {
      await repo.recordCounter(0, now);
      now = DateTime(2026, 3, 10, 9, 5);
      await repo.recordCounter(400, now);
      await start();

      expect(controller.todaySteps.value, 400);
    });
  });

  group('goal', () {
    test('set, progress, clear', () async {
      await start();
      expect(controller.goalProgress, isNull);

      await controller.setGoal(1000);
      expect(controller.goal.value, 1000);
      expect(await repo.dailyGoal(), 1000);

      controller.todaySteps.value = 250;
      expect(controller.goalProgress, 0.25);
      controller.todaySteps.value = 5000;
      expect(controller.goalProgress, 1.0); // capped

      await controller.setGoal(null);
      expect(controller.goal.value, isNull);
      expect(controller.goalProgress, isNull);
    });
  });

  group('flip detection', () {
    test('samples the accelerometer only while switched on', () async {
      await start();
      expect(sensors.accelListeners, 0);

      controller.setFlipDetection(true);
      expect(sensors.accelListeners, 1);
      expect(controller.faceDown.value, isNull);

      sensors.emitAccel(z(-9.8, 0));
      sensors.emitAccel(z(-9.8, 900));
      expect(controller.faceDown.value, isTrue);

      controller.setFlipDetection(false);
      expect(sensors.accelListeners, 0);
      expect(controller.faceDown.value, isNull);
    });
  });
}
