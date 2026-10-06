import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/core/services/location/geofence_service.dart';
import 'package:omnilife/core/services/location/location_service.dart';
import 'package:omnilife/data/datasources/local/saved_location_local_store.dart';
import 'package:omnilife/data/repositories/saved_location_repository_impl.dart';
import 'package:omnilife/presentation/controllers/places_controller.dart';
import 'package:omnilife/presentation/pages/map/map_page.dart';

import '../../support/location_sensor_fakes.dart';

/// Serves a 1x1 transparent PNG for every tile so tests never hit the
/// network.
class _BlankTileProvider extends TileProvider {
  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

const _lat = 12.9716;
const _lng = 77.5946;

void main() {
  late FakeLocationService location;
  late SavedLocationRepositoryImpl repo;
  late ForegroundGeofenceService geofence;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    location = FakeLocationService();
    repo = SavedLocationRepositoryImpl(
      localStore: InMemorySavedLocationStore(),
      remote: FakeRemote(),
    );
    geofence = ForegroundGeofenceService(locationService: location);
  });

  tearDown(() async {
    await geofence.dispose();
    Get.reset();
  });

  Future<void> pumpMap(
    WidgetTester tester, {
    List<String> places = const [],
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final id in places) {
      await repo.save(place(id, lat: _lat, lng: _lng));
    }
    Get.put(
      PlacesController(
        locationService: location,
        repository: repo,
        geofenceService: geofence,
        userIdProvider: () => 'u1',
        linkOptionsProvider: () => const [],
        idGenerator: () => 'new1',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MapPage(tileProvider: _BlankTileProvider()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('denied: explains, does not prompt until the user taps', (
    tester,
  ) async {
    location
      ..access = LocationAccess.denied
      ..accessAfterRequest = LocationAccess.granted
      ..position = fixNorthOf(_lat, _lng, 0);
    await pumpMap(tester);

    expect(location.requestCount, 0);
    expect(find.text('Show where you are'), findsOneWidget);
    expect(find.text('No saved places yet'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    await tester.tap(find.text('Use my location'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(location.requestCount, 1);
    expect(find.text('Show where you are'), findsNothing);
    expect(find.byKey(const Key('current_location_marker')), findsOneWidget);
  });

  testWidgets('permanently denied: Open settings opens app settings', (
    tester,
  ) async {
    location.access = LocationAccess.deniedForever;
    await pumpMap(tester);

    expect(find.text('Location access is off'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pump();

    expect(location.appSettingsOpened, 1);
    expect(location.requestCount, 0);
  });

  testWidgets('services disabled: Open settings opens location settings', (
    tester,
  ) async {
    location.access = LocationAccess.serviceDisabled;
    await pumpMap(tester);

    expect(find.text('Location is switched off'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pump();

    expect(location.locationSettingsOpened, 1);
  });

  testWidgets('unsupported: friendly message, map still shown', (tester) async {
    location.access = LocationAccess.unsupported;
    await pumpMap(tester);

    expect(find.text('Location is not available here'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('granted: lists places with distance and nearest summary', (
    tester,
  ) async {
    final far = fixNorthOf(_lat, _lng, 2500);
    await repo.save(
      place('far', lat: far.latitude, lng: far.longitude, radius: 150),
    );
    location
      ..access = LocationAccess.granted
      ..position = fixNorthOf(_lat, _lng, 0);
    await pumpMap(tester);

    expect(find.text('Place far'), findsWidgets);
    expect(find.text('2.5 km'), findsWidgets);
    expect(find.byKey(const Key('next_place_summary')), findsOneWidget);
    expect(find.text('Nearest place'), findsOneWidget);
    expect(find.byKey(const Key('geofence_switch')), findsOneWidget);
  });

  testWidgets('long-press on the map saves a named place', (tester) async {
    location.access = LocationAccess.denied;
    await pumpMap(tester);

    await tester.longPress(find.byType(FlutterMap));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('place_name_field')), findsOneWidget);

    // Empty name is rejected inline.
    await tester.tap(find.byKey(const Key('place_save_button')));
    await tester.pump();
    expect(find.text('Give this place a name'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('place_name_field')), 'Cafe');
    await tester.tap(find.byKey(const Key('place_save_button')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Cafe'), findsWidgets);
    expect(find.text('Saved "Cafe"'), findsOneWidget);
    expect((await repo.getLocations('u1')).single.name, 'Cafe');
  });
}
