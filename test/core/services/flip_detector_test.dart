import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/sensors/flip_detector.dart';
import 'package:omnilife/core/services/sensors/sensor_service.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  AccelSample z(double value, int ms) => AccelSample(
    x: 0.2,
    y: 0.3,
    z: value,
    timestamp: t0.add(Duration(milliseconds: ms)),
  );

  late FakeSensorService sensors;
  late FlipDetector detector;
  late List<bool> states;

  setUp(() {
    sensors = FakeSensorService();
    detector = FlipDetector(
      sensors: sensors,
      debounce: const Duration(milliseconds: 500),
    );
    states = [];
  });

  test('does not touch the accelerometer until someone listens', () {
    detector.watch(); // never listened
    expect(sensors.accelListeners, 0);
  });

  test('reports face down only after the debounce interval', () async {
    final sub = detector.watch().listen(states.add);
    sensors.emitAccel(z(-9.8, 0));
    sensors.emitAccel(z(-9.8, 300));
    expect(states, isEmpty); // 300 ms < 500 ms
    sensors.emitAccel(z(-9.8, 500));
    expect(states, [true]);
    // Holding the pose does not repeat the event.
    sensors.emitAccel(z(-9.7, 900));
    sensors.emitAccel(z(-9.8, 1500));
    expect(states, [true]);
    await sub.cancel();
  });

  test('a brief flip (shorter than debounce) is ignored', () async {
    final sub = detector.watch().listen(states.add);
    sensors.emitAccel(z(9.8, 0));
    sensors.emitAccel(z(9.8, 600)); // stable face up
    expect(states, [false]);

    sensors.emitAccel(z(-9.8, 700));
    sensors.emitAccel(z(-9.8, 900)); // only 200 ms face down
    sensors.emitAccel(z(9.8, 1000)); // back up
    sensors.emitAccel(z(9.8, 1700));
    expect(states, [false]);
    await sub.cancel();
  });

  test('flip down then up is reported in order', () async {
    final sub = detector.watch().listen(states.add);
    sensors.emitAccel(z(9.8, 0));
    sensors.emitAccel(z(9.8, 500));
    sensors.emitAccel(z(-9.8, 1000));
    sensors.emitAccel(z(-9.8, 1500));
    sensors.emitAccel(z(9.8, 2000));
    sensors.emitAccel(z(9.8, 2500));
    expect(states, [false, true, false]);
    await sub.cancel();
  });

  test('readings in the dead band hold the previous state', () async {
    final sub = detector.watch().listen(states.add);
    sensors.emitAccel(z(-9.8, 0));
    sensors.emitAccel(z(-9.8, 500));
    expect(states, [true]);
    // Tilted (z between -4 and -7): neither up nor down, no change.
    for (var i = 1; i <= 10; i++) {
      sensors.emitAccel(z(-5.5, 500 + i * 200));
    }
    expect(states, [true]);
    await sub.cancel();
  });

  test('interrupting a candidate restarts the debounce clock', () async {
    final sub = detector.watch().listen(states.add);
    sensors.emitAccel(z(-9.8, 0));
    sensors.emitAccel(z(-9.8, 400));
    sensors.emitAccel(z(9.8, 450)); // contradicts: new candidate (up)
    sensors.emitAccel(z(-9.8, 500)); // candidate down again, clock restarts
    sensors.emitAccel(z(-9.8, 900)); // only 400 ms since restart
    expect(states, isEmpty);
    sensors.emitAccel(z(-9.8, 1000));
    expect(states, [true]);
    await sub.cancel();
  });

  test('cancelling the subscription releases the sensor', () async {
    final sub = detector.watch().listen(states.add);
    expect(sensors.accelListeners, 1);
    await sub.cancel();
    expect(sensors.accelListeners, 0);
  });
}
