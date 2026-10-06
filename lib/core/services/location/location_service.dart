import '../../utils/geo.dart';

/// Where the user stands with respect to location access. The UI maps each
/// value to a friendly state; nothing here ever throws for "not allowed".
enum LocationAccess {
  /// Permission granted and the device location service is on.
  granted,

  /// Not granted yet (never asked, or denied once). Asking again is allowed.
  denied,

  /// Denied permanently; only system settings can change it.
  deniedForever,

  /// Permission may be fine but location is switched off on the device.
  serviceDisabled,

  /// No location capability on this platform / browser.
  unsupported,
}

/// A single position fix, decoupled from the geolocator plugin type so the
/// domain, the geofence evaluator and tests never import a plugin.
class GeoPosition {
  const GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters = 0,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Estimated horizontal error radius in metres (0 when unknown).
  final double accuracyMeters;

  double distanceTo(double lat, double lng) =>
      haversineMeters(latitude, longitude, lat, lng);
}

/// Thrown by [LocationService.currentPosition] when no fix can be had.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Device location behind an interface.
///
/// Rules for implementations and callers:
/// * Permission is requested only from [requestAccess], which the UI calls
///   in response to a user tap. [checkAccess] never prompts, so it is safe
///   on screen open. Nothing asks for permission at app start.
/// * Denial / permanent denial / disabled services are reported as
///   [LocationAccess] values, not exceptions.
abstract class LocationService {
  /// Current state without prompting.
  Future<LocationAccess> checkAccess();

  /// Prompts the user if the state allows it, then returns the new state.
  Future<LocationAccess> requestAccess();

  /// One fix. Throws [LocationUnavailableException] when none is available.
  Future<GeoPosition> currentPosition();

  /// Continuous fixes. Only subscribe while the UI or geofencing needs it;
  /// cancel the subscription to stop GPS use.
  Stream<GeoPosition> positionStream({int distanceFilterMeters = 10});

  /// Great-circle distance in metres.
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  );

  /// Opens the app's page in system settings (for [LocationAccess.deniedForever]).
  /// Returns false when it could not be opened (e.g. on web).
  Future<bool> openAppSettings();

  /// Opens the device location settings (for [LocationAccess.serviceDisabled]).
  Future<bool> openLocationSettings();
}
