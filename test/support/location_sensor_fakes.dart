import 'dart:async';

import 'package:omnilife/core/services/location/location_service.dart';
import 'package:omnilife/core/services/sensors/sensor_service.dart';
import 'package:omnilife/core/utils/geo.dart';
import 'package:omnilife/data/datasources/remote/user_doc_remote.dart';
import 'package:omnilife/domain/entities/saved_location.dart';

/// Scriptable [LocationService]; never touches a platform channel.
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.access = LocationAccess.denied,
    this.accessAfterRequest,
    this.position,
  });

  LocationAccess access;

  /// What [requestAccess] resolves to (defaults to the current [access]).
  LocationAccess? accessAfterRequest;
  GeoPosition? position;

  int requestCount = 0;
  int checkCount = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;
  bool settingsOpenSucceeds = true;
  int activeStreamListeners = 0;

  final _positions = StreamController<GeoPosition>.broadcast(sync: true);

  void emit(GeoPosition p) => _positions.add(p);

  @override
  Future<LocationAccess> checkAccess() async {
    checkCount++;
    return access;
  }

  @override
  Future<LocationAccess> requestAccess() async {
    requestCount++;
    access = accessAfterRequest ?? access;
    return access;
  }

  @override
  Future<GeoPosition> currentPosition() async {
    final p = position;
    if (p == null) throw const LocationUnavailableException('No fix');
    return p;
  }

  @override
  Stream<GeoPosition> positionStream({int distanceFilterMeters = 10}) {
    late StreamController<GeoPosition> c;
    StreamSubscription<GeoPosition>? sub;
    c = StreamController<GeoPosition>(
      sync: true,
      onListen: () {
        activeStreamListeners++;
        sub = _positions.stream.listen(c.add);
      },
      onCancel: () async {
        activeStreamListeners--;
        await sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  double distanceBetween(double a, double b, double c, double d) =>
      haversineMeters(a, b, c, d);

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return settingsOpenSucceeds;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return settingsOpenSucceeds;
  }
}

/// In-memory [UserDocRemote] that can be switched offline.
class FakeRemote implements UserDocRemote {
  final Map<String, Map<String, Map<String, dynamic>>> docs = {};
  bool offline = false;
  int setCalls = 0;

  Map<String, dynamic>? doc(String uid, String col, String id) =>
      docs['$uid/$col']?[id];

  @override
  Future<void> set(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    setCalls++;
    if (offline) throw Exception('offline');
    final col = docs.putIfAbsent('$uid/$collection', () => {});
    // Merge semantics like Firestore SetOptions(merge: true).
    col[docId] = {...?col[docId], ...data};
  }

  @override
  Future<void> delete(String uid, String collection, String docId) async {
    if (offline) throw Exception('offline');
    docs['$uid/$collection']?.remove(docId);
  }

  @override
  Future<List<Map<String, dynamic>>> list(String uid, String collection) async {
    if (offline) throw Exception('offline');
    return [
      for (final e in (docs['$uid/$collection'] ?? {}).entries)
        {'id': e.key, ...e.value},
    ];
  }
}

/// Scriptable [SensorService].
class FakeSensorService implements SensorService {
  FakeSensorService({
    this.supported = true,
    this.access = SensorAccess.denied,
    this.accessAfterRequest,
  });

  bool supported;
  SensorAccess access;
  SensorAccess? accessAfterRequest;
  int requestCount = 0;
  int settingsOpened = 0;

  int stepListeners = 0;
  int accelListeners = 0;

  final _steps = StreamController<int>.broadcast(sync: true);
  final _accel = StreamController<AccelSample>.broadcast(sync: true);

  void emitSteps(int counter) => _steps.add(counter);
  void emitAccel(AccelSample s) => _accel.add(s);

  @override
  bool get isSupported => supported;

  @override
  Future<SensorAccess> checkStepAccess() async =>
      supported ? access : SensorAccess.unsupported;

  @override
  Future<SensorAccess> requestStepAccess() async {
    requestCount++;
    if (!supported) return SensorAccess.unsupported;
    access = accessAfterRequest ?? access;
    return access;
  }

  @override
  Stream<int> stepCounts() {
    late StreamController<int> c;
    StreamSubscription<int>? sub;
    c = StreamController<int>(
      sync: true,
      onListen: () {
        stepListeners++;
        sub = _steps.stream.listen(c.add);
      },
      onCancel: () async {
        stepListeners--;
        await sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  Stream<AccelSample> accelerometer({
    Duration samplingPeriod = const Duration(milliseconds: 200),
  }) {
    late StreamController<AccelSample> c;
    StreamSubscription<AccelSample>? sub;
    c = StreamController<AccelSample>(
      sync: true,
      onListen: () {
        accelListeners++;
        sub = _accel.stream.listen(c.add);
      },
      onCancel: () async {
        accelListeners--;
        await sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A fix near a base point, offset north by [metersNorth].
GeoPosition fixNorthOf(
  double lat,
  double lng,
  double metersNorth, {
  double accuracy = 5,
  DateTime? at,
}) {
  // 1 degree latitude ~ 111,195 m.
  return GeoPosition(
    latitude: lat + metersNorth / 111195.0,
    longitude: lng,
    accuracyMeters: accuracy,
    timestamp: at ?? DateTime(2026, 1, 1, 12),
  );
}

SavedLocation place(
  String id, {
  double lat = 12.9716,
  double lng = 77.5946,
  double radius = 100,
  String userId = 'u1',
  String? taskId,
  String? eventId,
  DateTime? created,
}) {
  final t = created ?? DateTime(2026, 1, 1, 9);
  return SavedLocation(
    id: id,
    userId: userId,
    name: 'Place $id',
    latitude: lat,
    longitude: lng,
    radiusMeters: radius,
    linkedTaskId: taskId,
    linkedEventId: eventId,
    createdAt: t,
    updatedAt: t,
  );
}
