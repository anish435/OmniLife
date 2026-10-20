import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/sensors/sensor_service.dart';
import 'package:omnilife/core/services/sensors/shake_detector.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  AccelSample sample(double x, double y, double z, int ms) => AccelSample(
    x: x,
    y: y,
    z: z,
    timestamp: t0.add(Duration(milliseconds: ms)),
  );

  AccelSample shake(int ms, {double val = 18.5}) =>
      sample(val, 0, 0, ms); // magnitude 18.5 > 18.0

  AccelSample rest(int ms) => sample(0, 0, 9.8, ms); // at rest, magnitude ~9.8

  late FakeSensorService sensors;
  late ShakeDetector detector;
  late int triggerCount;

  setUp(() {
    sensors = FakeSensorService();
    detector = ShakeDetector(
      sensors: sensors,
      shakeThreshold: 18.0,
      minShakeInterval: const Duration(milliseconds: 250),
      maxDoubleShakeInterval: const Duration(milliseconds: 1500),
      cooldown: const Duration(milliseconds: 1500),
    );
    triggerCount = 0;
  });

  test('does not touch accelerometer until someone listens', () {
    detector.watchDoubleShake(); // unlistened
    expect(sensors.accelListeners, 0);
  });

  test('weak movement below threshold never triggers', () async {
    final sub = detector.watchDoubleShake().listen((_) => triggerCount++);
    sensors.emitAccel(rest(0));
    sensors.emitAccel(sample(5.0, 5.0, 9.8, 500)); // ~12.1 m/s^2 < 18.0
    sensors.emitAccel(sample(6.0, 6.0, 9.8, 1000));
    expect(triggerCount, 0);
    await sub.cancel();
  });

  test('a single shake never triggers a double-shake', () async {
    final sub = detector.watchDoubleShake().listen((_) => triggerCount++);
    sensors.emitAccel(shake(0));
    sensors.emitAccel(rest(200));
    sensors.emitAccel(rest(2000));
    expect(triggerCount, 0);
    await sub.cancel();
  });

  test('rapid jitter within minShakeInterval is treated as one shake', () async {
    final sub = detector.watchDoubleShake().listen((_) => triggerCount++);
    sensors.emitAccel(shake(0));
    sensors.emitAccel(shake(50));
    sensors.emitAccel(shake(100));
    sensors.emitAccel(shake(200)); // all < 250ms
    expect(triggerCount, 0);
    await sub.cancel();
  });

  test('two shakes within the double-shake window trigger exactly once', () async {
    final sub = detector.watchDoubleShake().listen((_) => triggerCount++);
    // First shake
    sensors.emitAccel(shake(0));
    sensors.emitAccel(rest(100));

    // Second shake at 400ms (250ms <= 400ms <= 1500ms)
    sensors.emitAccel(shake(400));
    expect(triggerCount, 1);

    // Cooldown prevents immediate re-trigger from residual vibration
    sensors.emitAccel(shake(600));
    sensors.emitAccel(shake(1000));
    expect(triggerCount, 1);

    await sub.cancel();
  });

  test('shakes spaced too far apart (> maxDoubleShakeInterval) do not trigger', () async {
    final sub = detector.watchDoubleShake().listen((_) => triggerCount++);
    // First shake at 0ms
    sensors.emitAccel(shake(0));
    sensors.emitAccel(rest(500));

    // Second shake at 1800ms (1800ms > 1500ms window)
    // This resets the candidate to 1800ms
    sensors.emitAccel(shake(1800));
    expect(triggerCount, 0);

    // A third shake at 2200ms (400ms after the second shake) DOES trigger!
    sensors.emitAccel(shake(2200));
    expect(triggerCount, 1);

    await sub.cancel();
  });

  test('cancelling stream releases the sensor subscription', () async {
    final sub = detector.watchDoubleShake().listen((_) {});
    expect(sensors.accelListeners, 1);
    await sub.cancel();
    expect(sensors.accelListeners, 0);
  });
}
