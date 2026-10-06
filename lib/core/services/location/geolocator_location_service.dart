import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// [LocationService] on top of the `geolocator` plugin (Android, iOS and web
/// via the browser Geolocation API; desktop platforms report
/// [LocationAccess.unsupported] through the plugin's own checks).
///
/// Not unit tested (it is a thin plugin shim); everything with logic sits
/// behind [LocationService] and is tested with fakes.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationAccess> checkAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceDisabled;
      }
      return _map(await Geolocator.checkPermission());
    } catch (_) {
      return LocationAccess.unsupported;
    }
  }

  @override
  Future<LocationAccess> requestAccess() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final mapped = _map(permission);
      if (mapped != LocationAccess.granted) return mapped;
      // Permission is fine; report switched-off device services separately
      // so the UI can offer "Open location settings".
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceDisabled;
      }
      return LocationAccess.granted;
    } catch (_) {
      return LocationAccess.unsupported;
    }
  }

  LocationAccess _map(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccess.granted;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
    }
  }

  GeoPosition _fromPosition(Position p) => GeoPosition(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: p.accuracy,
    timestamp: p.timestamp,
  );

  @override
  Future<GeoPosition> currentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return _fromPosition(p);
    } on TimeoutException {
      throw const LocationUnavailableException(
        'Could not get a location fix in time. Try again outdoors or near a window.',
      );
    } catch (e) {
      throw LocationUnavailableException('Location unavailable: $e');
    }
  }

  @override
  Stream<GeoPosition> positionStream({int distanceFilterMeters = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    ).map(_fromPosition);
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) => Geolocator.distanceBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
  );

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
