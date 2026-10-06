import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/location/geofence_service.dart';
import 'package:omnilife/core/utils/geo.dart';

import '../../support/location_sensor_fakes.dart';

const _lat = 12.9716;
const _lng = 77.5946;

void main() {
  group('haversineMeters', () {
    test('matches the known distance of one degree of latitude', () {
      final d = haversineMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 100));
    });

    test('is zero for identical points and symmetric', () {
      expect(haversineMeters(_lat, _lng, _lat, _lng), 0);
      expect(
        haversineMeters(_lat, _lng, 13.0, 77.7),
        closeTo(haversineMeters(13.0, 77.7, _lat, _lng), 1e-6),
      );
    });

    test('formatDistance switches to km at 1000 m', () {
      expect(formatDistance(85.4), '85 m');
      expect(formatDistance(1400), '1.4 km');
      expect(formatDistance(25000), '25 km');
    });
  });

  group('GeofenceEvaluator', () {
    late GeofenceEvaluator evaluator;
    final home = place('home', lat: _lat, lng: _lng, radius: 100);

    setUp(() => evaluator = GeofenceEvaluator());

    List<GeofenceEvent> feed(double metersNorth, {double accuracy = 5}) =>
        evaluator.evaluate(
          fixNorthOf(_lat, _lng, metersNorth, accuracy: accuracy),
          [home],
        );

    test('a single fix inside does not enter (needs confirmation)', () {
      expect(feed(10), isEmpty);
      expect(evaluator.insideIds, isEmpty);
    });

    test('two consecutive fixes inside emit exactly one enter', () {
      feed(50);
      final events = feed(40);
      expect(events, hasLength(1));
      expect(events.single.transition, GeofenceTransition.enter);
      expect(events.single.location.id, 'home');
      expect(evaluator.insideIds, {'home'});
      // Staying inside emits nothing more.
      expect(feed(30), isEmpty);
      expect(feed(20), isEmpty);
    });

    test('an outlier fix between inside fixes resets the confirmation', () {
      feed(50); // streak 1
      feed(400); // contradicts: streak resets
      expect(feed(50), isEmpty); // streak 1 again
      expect(evaluator.insideIds, isEmpty);
      expect(feed(50), hasLength(1));
    });

    test('jitter around the radius edge does not flap once inside', () {
      feed(50);
      feed(50); // entered
      // Edge for radius 100 is 100 m; exit buffer is max(25, 20) = 25 m.
      final events = <GeofenceEvent>[];
      for (final d in [99, 101, 98, 110, 102, 120, 99, 124, 100, 105]) {
        events.addAll(feed(d.toDouble()));
      }
      expect(events, isEmpty);
      expect(evaluator.insideIds, {'home'});
    });

    test('leaving needs to pass radius + buffer on consecutive fixes', () {
      feed(50);
      feed(50); // entered
      expect(feed(126), isEmpty); // beyond 125 m: streak 1
      final events = feed(130); // streak 2: exit
      expect(events, hasLength(1));
      expect(events.single.transition, GeofenceTransition.exit);
      expect(evaluator.insideIds, isEmpty);
    });

    test('a fix back inside the band cancels a pending exit', () {
      feed(50);
      feed(50);
      feed(150); // streak 1 toward exit
      feed(110); // back in the hysteresis band: resets
      expect(feed(150), isEmpty);
      expect(evaluator.insideIds, {'home'});
    });

    test('re-entering after exit emits a second enter', () {
      feed(50);
      feed(50);
      feed(200);
      feed(200);
      feed(60);
      final events = feed(60);
      expect(events.map((e) => e.transition), [GeofenceTransition.enter]);
    });

    test('large radii use a proportional exit buffer', () {
      expect(evaluator.exitBufferFor(100), 25);
      expect(evaluator.exitBufferFor(1000), 200);
    });

    test('imprecise fixes are ignored entirely', () {
      expect(feed(10, accuracy: 500), isEmpty);
      expect(feed(10, accuracy: 500), isEmpty);
      expect(evaluator.insideIds, isEmpty);
      feed(10);
      expect(feed(10), hasLength(1));
    });

    test('confirmations: 1 reacts immediately', () {
      final fast = GeofenceEvaluator(confirmations: 1);
      final events = fast.evaluate(fixNorthOf(_lat, _lng, 10), [home]);
      expect(events.single.isEnter, isTrue);
    });

    test('tracks several places independently and drops deleted ones', () {
      final far = place('far', lat: _lat + 0.05, lng: _lng, radius: 100);
      final both = [home, far];
      evaluator.evaluate(fixNorthOf(_lat, _lng, 10), both);
      final events = evaluator.evaluate(fixNorthOf(_lat, _lng, 10), both);
      expect(events.map((e) => e.location.id), ['home']);
      expect(evaluator.insideIds, {'home'});

      // Home deleted: state is forgotten, no stale inside.
      evaluator.evaluate(fixNorthOf(_lat, _lng, 10), [far]);
      expect(evaluator.insideIds, isEmpty);
    });
  });
}
