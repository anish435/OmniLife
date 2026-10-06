import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/location/geofence_service.dart';
import 'package:omnilife/core/services/location/location_service.dart';

import '../../support/location_sensor_fakes.dart';

void main() {
  const lat = 12.9716;
  const lng = 77.5946;

  test('emits enter and exit events from the position stream', () async {
    final location = FakeLocationService(access: LocationAccess.granted);
    final service = ForegroundGeofenceService(locationService: location);
    final events = <GeofenceEvent>[];
    service.events.listen(events.add);
    service.updateLocations([place('home', lat: lat, lng: lng)]);

    await service.start();
    expect(service.isRunning, isTrue);
    expect(location.activeStreamListeners, 1);

    location.emit(fixNorthOf(lat, lng, 20));
    location.emit(fixNorthOf(lat, lng, 20));
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.transition), [GeofenceTransition.enter]);
    expect(service.insideLocationIds, {'home'});

    location.emit(fixNorthOf(lat, lng, 500));
    location.emit(fixNorthOf(lat, lng, 500));
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.transition), [
      GeofenceTransition.enter,
      GeofenceTransition.exit,
    ]);

    await service.dispose();
  });

  test('stop releases the GPS subscription and clears inside state', () async {
    final location = FakeLocationService(access: LocationAccess.granted);
    final service = ForegroundGeofenceService(locationService: location);
    service.updateLocations([place('home', lat: lat, lng: lng)]);
    await service.start();
    location.emit(fixNorthOf(lat, lng, 5));
    location.emit(fixNorthOf(lat, lng, 5));
    expect(service.insideLocationIds, {'home'});

    await service.stop();

    expect(location.activeStreamListeners, 0);
    expect(service.isRunning, isFalse);
    expect(service.insideLocationIds, isEmpty);
    await service.dispose();
  });

  test('start is idempotent (one GPS subscription)', () async {
    final location = FakeLocationService(access: LocationAccess.granted);
    final service = ForegroundGeofenceService(locationService: location);
    await service.start();
    await service.start();
    expect(location.activeStreamListeners, 1);
    await service.dispose();
  });
}
