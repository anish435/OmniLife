import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/location/geofence_service.dart';
import 'package:omnilife/core/services/location/location_service.dart';
import 'package:omnilife/data/datasources/local/saved_location_local_store.dart';
import 'package:omnilife/data/repositories/saved_location_repository_impl.dart';
import 'package:omnilife/presentation/controllers/places_controller.dart';

import '../../support/location_sensor_fakes.dart';

const _lat = 12.9716;
const _lng = 77.5946;

void main() {
  late FakeLocationService location;
  late FakeRemote remote;
  late SavedLocationRepositoryImpl repo;
  late ForegroundGeofenceService geofence;
  late PlacesController controller;
  String? uid;
  var idCounter = 0;

  Future<void> start({List<String> existing = const []}) async {
    for (final id in existing) {
      await repo.save(place(id, lat: _lat, lng: _lng));
    }
    controller.onInit();
    await pumpEventQueue();
  }

  setUp(() {
    uid = 'u1';
    idCounter = 0;
    location = FakeLocationService();
    remote = FakeRemote();
    repo = SavedLocationRepositoryImpl(
      localStore: InMemorySavedLocationStore(),
      remote: remote,
    );
    geofence = ForegroundGeofenceService(locationService: location);
    controller = PlacesController(
      locationService: location,
      repository: repo,
      geofenceService: geofence,
      userIdProvider: () => uid,
      linkOptionsProvider: () => const [],
      idGenerator: () => 'id${++idCounter}',
      clock: () => DateTime(2026, 1, 1, 10),
    );
  });

  tearDown(() async {
    controller.onClose();
    await geofence.dispose();
  });

  group('permission state machine', () {
    test('opening the screen never prompts for permission', () async {
      location.access = LocationAccess.denied;
      await start();

      expect(location.requestCount, 0);
      expect(controller.access.value, LocationAccess.denied);
      expect(controller.position.value, isNull);
      expect(location.activeStreamListeners, 0);
    });

    test('already granted: shows position without prompting', () async {
      location
        ..access = LocationAccess.granted
        ..position = fixNorthOf(_lat, _lng, 0);
      await start();

      expect(location.requestCount, 0);
      expect(controller.hasAccess, isTrue);
      expect(controller.position.value, isNotNull);
      expect(location.activeStreamListeners, 1);
    });

    test('tap on "use my location" prompts once and starts watching', () async {
      location
        ..access = LocationAccess.denied
        ..accessAfterRequest = LocationAccess.granted
        ..position = fixNorthOf(_lat, _lng, 0);
      await start();

      await controller.enableLocation();

      expect(location.requestCount, 1);
      expect(controller.access.value, LocationAccess.granted);
      expect(controller.position.value, isNotNull);
      expect(controller.isLocating.value, isFalse);

      // Live updates flow through.
      location.emit(fixNorthOf(_lat, _lng, 50));
      expect(controller.position.value!.latitude, greaterThan(_lat));
    });

    test('denial leaves a friendly denied state and no position', () async {
      location
        ..access = LocationAccess.denied
        ..accessAfterRequest = LocationAccess.denied;
      await start();

      await controller.enableLocation();

      expect(controller.access.value, LocationAccess.denied);
      expect(controller.position.value, isNull);
      expect(location.activeStreamListeners, 0);
      // Can ask again later (not deniedForever).
      await controller.enableLocation();
      expect(location.requestCount, 2);
    });

    test('permanent denial offers app settings, not another prompt', () async {
      location
        ..access = LocationAccess.denied
        ..accessAfterRequest = LocationAccess.deniedForever;
      await start();
      await controller.enableLocation();
      expect(controller.access.value, LocationAccess.deniedForever);

      await controller.openSettings();

      expect(location.appSettingsOpened, 1);
      expect(location.locationSettingsOpened, 0);
    });

    test('services disabled opens the location settings screen', () async {
      location.access = LocationAccess.serviceDisabled;
      await start();
      expect(controller.access.value, LocationAccess.serviceDisabled);

      await controller.openSettings();

      expect(location.locationSettingsOpened, 1);
      expect(location.appSettingsOpened, 0);
    });

    test('settings that cannot open produce a notice (e.g. web)', () async {
      location
        ..access = LocationAccess.deniedForever
        ..settingsOpenSucceeds = false;
      await start();

      await controller.openSettings();

      expect(controller.notice.value, contains('Could not open settings'));
    });

    test('recheck after returning from settings picks up the grant', () async {
      location
        ..access = LocationAccess.deniedForever
        ..position = fixNorthOf(_lat, _lng, 0);
      await start();
      expect(controller.hasAccess, isFalse);

      location.access = LocationAccess.granted; // user flipped it in settings
      await controller.recheckAccess();

      expect(controller.hasAccess, isTrue);
      expect(controller.position.value, isNotNull);
    });

    test('unsupported platform stays usable without a position', () async {
      location.access = LocationAccess.unsupported;
      await start();

      final saved = await controller.saveLocation(
        name: 'Cafe',
        latitude: 1,
        longitude: 2,
      );

      expect(controller.access.value, LocationAccess.unsupported);
      expect(saved, isNotNull);
    });

    test('a failed fix shows a notice and keeps access state', () async {
      location
        ..access = LocationAccess.denied
        ..accessAfterRequest = LocationAccess.granted
        ..position = null; // no fix available
      await start();

      await controller.enableLocation();

      expect(controller.hasAccess, isTrue);
      expect(controller.position.value, isNull);
      expect(controller.notice.value, 'No fix');
    });
  });

  group('saved places', () {
    test('loads existing places for the signed-in user', () async {
      await start(existing: ['a', 'b']);
      expect(controller.locations.map((l) => l.id), ['a', 'b']);
      expect(controller.isLoading.value, isFalse);
    });

    test('save persists, updates the list and confirms immediately', () async {
      await start();

      final saved = await controller.saveLocation(
        name: '  Gym  ',
        latitude: 1.5,
        longitude: 2.5,
        radiusMeters: 150,
        linkedTaskId: 't1',
      );

      expect(saved!.name, 'Gym');
      expect(saved.id, 'id1');
      expect(controller.locations.single.linkedTaskId, 't1');
      expect(controller.notice.value, 'Saved "Gym"');
      // Persisted, not just in memory:
      expect((await repo.getLocations('u1')).single.name, 'Gym');
      await repo.flush();
      expect(remote.doc('u1', 'locations', 'id1'), isNotNull);
    });

    test('radius is clamped to the allowed range', () async {
      await start();
      final tiny = await controller.saveLocation(
        name: 'A',
        latitude: 0,
        longitude: 0,
        radiusMeters: 1,
      );
      final huge = await controller.saveLocation(
        name: 'B',
        latitude: 0,
        longitude: 0,
        radiusMeters: 999999,
      );
      expect(tiny!.radiusMeters, 20);
      expect(huge!.radiusMeters, 5000);
    });

    test(
      'blank name and signed-out state are rejected with a message',
      () async {
        await start();
        expect(
          await controller.saveLocation(name: '  ', latitude: 0, longitude: 0),
          isNull,
        );
        expect(controller.notice.value, 'Give the place a name.');

        uid = null;
        expect(
          await controller.saveLocation(name: 'X', latitude: 0, longitude: 0),
          isNull,
        );
        expect(controller.notice.value, 'Sign in to save places.');
        expect(controller.locations, isEmpty);
      },
    );

    test('update and delete persist and refresh the list', () async {
      await start(existing: ['a']);
      final a = controller.locations.single;

      await controller.updateLocation(a, name: 'Renamed', radiusMeters: 400);
      expect(controller.locations.single.name, 'Renamed');
      expect((await repo.getLocations('u1')).single.radiusMeters, 400);

      await controller.deleteLocation(controller.locations.single);
      expect(controller.locations, isEmpty);
      expect(await repo.getLocations('u1'), isEmpty);
      expect(controller.notice.value, 'Deleted "Renamed"');
    });

    test('link can be cleared on update', () async {
      await start();
      final p = (await controller.saveLocation(
        name: 'A',
        latitude: 0,
        longitude: 0,
        linkedEventId: 'e1',
      ))!;
      await controller.updateLocation(p, clearLinks: true);
      expect(controller.locations.single.linkedEventId, isNull);
    });
  });

  group('distances', () {
    test('distance to a place and the nearest not-yet-reached place', () async {
      location
        ..access = LocationAccess.granted
        ..position = fixNorthOf(_lat, _lng, 0);
      await start();
      // inside "here" (radius 100), 3 km and 1 km away others
      await controller.saveLocation(
        name: 'Here',
        latitude: _lat,
        longitude: _lng,
      );
      final far = fixNorthOf(_lat, _lng, 3000);
      final near = fixNorthOf(_lat, _lng, 1000);
      await controller.saveLocation(
        name: 'Far',
        latitude: far.latitude,
        longitude: far.longitude,
      );
      await controller.saveLocation(
        name: 'Near',
        latitude: near.latitude,
        longitude: near.longitude,
      );

      final nearPlace = controller.locations.firstWhere(
        (l) => l.name == 'Near',
      );
      expect(controller.distanceTo(nearPlace), closeTo(1000, 5));
      expect(controller.distanceLabelTo(nearPlace), '1.0 km');
      // "Here" is closest overall but already reached, so Near is next.
      expect(controller.nextPlace!.name, 'Near');
    });

    test('no position: no distances and no next place', () async {
      await start(existing: ['a']);
      expect(controller.distanceTo(controller.locations.single), isNull);
      expect(controller.nextPlace, isNull);
    });
  });

  group('geofence toggle', () {
    test('needs a saved place before it can be turned on', () async {
      location.access = LocationAccess.granted;
      await start();

      await controller.setGeofencing(true);

      expect(controller.geofenceEnabled.value, isFalse);
      expect(controller.notice.value, contains('Save a place first'));
    });

    test('asks for location when turned on without access', () async {
      location
        ..access = LocationAccess.denied
        ..accessAfterRequest = LocationAccess.denied;
      await start(existing: ['a']);

      await controller.setGeofencing(true);

      expect(location.requestCount, 1);
      expect(controller.geofenceEnabled.value, isFalse);
      expect(geofence.isRunning, isFalse);
    });

    test(
      'enter/exit events surface as state and are exposed as a stream',
      () async {
        location
          ..access = LocationAccess.granted
          ..position = fixNorthOf(_lat, _lng, 500);
        await start(existing: ['home']);
        final events = <GeofenceEvent>[];
        controller.geofenceEvents.listen(events.add);

        await controller.setGeofencing(true);
        expect(controller.geofenceEnabled.value, isTrue);
        expect(geofence.isRunning, isTrue);

        location.emit(fixNorthOf(_lat, _lng, 10));
        location.emit(fixNorthOf(_lat, _lng, 10));
        await pumpEventQueue();
        expect(events.single.isEnter, isTrue);
        expect(controller.insideIds, {'home'});
        expect(controller.notice.value, 'Arrived at Place home');

        location.emit(fixNorthOf(_lat, _lng, 800));
        location.emit(fixNorthOf(_lat, _lng, 800));
        await pumpEventQueue();
        expect(events.last.transition, GeofenceTransition.exit);
        expect(controller.insideIds, isEmpty);
        expect(controller.recentEvents, hasLength(2));
      },
    );

    test('turning off and closing the screen release GPS', () async {
      location
        ..access = LocationAccess.granted
        ..position = fixNorthOf(_lat, _lng, 0);
      await start(existing: ['home']);
      await controller.setGeofencing(true);
      // one subscription for the map position, one for geofencing
      expect(location.activeStreamListeners, 2);

      await controller.setGeofencing(false);
      expect(location.activeStreamListeners, 1);
      expect(controller.geofenceEnabled.value, isFalse);

      controller.onClose();
      await pumpEventQueue();
      expect(location.activeStreamListeners, 0);
    });

    test('deleting a place stops tracking it', () async {
      location
        ..access = LocationAccess.granted
        ..position = fixNorthOf(_lat, _lng, 0);
      await start(existing: ['home']);
      await controller.setGeofencing(true);
      location.emit(fixNorthOf(_lat, _lng, 5));
      location.emit(fixNorthOf(_lat, _lng, 5));
      await pumpEventQueue();
      expect(controller.insideIds, {'home'});

      await controller.deleteLocation(controller.locations.single);

      expect(controller.insideIds, isEmpty);
    });
  });
}
