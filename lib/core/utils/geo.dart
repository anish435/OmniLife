import 'dart:math' as math;

/// Mean Earth radius in metres (IUGG).
const double earthRadiusMeters = 6371008.8;

/// Great-circle distance between two WGS84 points, in metres (haversine).
///
/// Pure Dart on purpose: the geofence evaluator and the UI use it, so it
/// never needs a platform channel (and tests never need a fake plugin).
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Human friendly distance: "85 m", "1.4 km".
String formatDistance(double meters) {
  if (meters.isNaN || meters.isInfinite) return '-';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}
