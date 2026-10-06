import 'dart:async';

import '../../../domain/entities/saved_location.dart';
import 'location_service.dart';

/// Which way the user crossed a [SavedLocation] boundary.
enum GeofenceTransition { enter, exit }

/// Emitted when the user enters or leaves a saved place. The notification
/// layer (and anything else) can subscribe to [GeofenceService.events] and
/// use [location.linkedEventId] / [location.linkedTaskId] to find what to
/// remind the user about.
class GeofenceEvent {
  const GeofenceEvent({
    required this.location,
    required this.transition,
    required this.distanceMeters,
    required this.timestamp,
  });

  final SavedLocation location;
  final GeofenceTransition transition;

  /// Distance from the saved place's centre at the fix that confirmed it.
  final double distanceMeters;

  /// Timestamp of the position fix that confirmed the transition.
  final DateTime timestamp;

  bool get isEnter => transition == GeofenceTransition.enter;

  @override
  String toString() =>
      'GeofenceEvent(${location.name}, ${transition.name}, '
      '${distanceMeters.round()} m)';
}

/// Turns saved locations into enter/exit events.
///
/// IMPORTANT LIMITATION: the only implementation here,
/// [ForegroundGeofenceService], is driven by the in-app position stream and
/// therefore works only while the app process is alive and receiving
/// location updates. True background geofencing (events while the app is
/// closed, battery-efficient OS region monitoring) needs a native plugin
/// (Android GeofencingClient / iOS CLCircularRegion, usually with a
/// background-location permission and a foreground service). That is out of
/// scope; this interface is the seam where such an implementation would
/// plug in without changing consumers.
abstract class GeofenceService {
  /// Broadcast stream of confirmed transitions.
  Stream<GeofenceEvent> get events;

  /// Ids of saved locations the user is currently considered inside.
  Set<String> get insideLocationIds;

  bool get isRunning;

  /// Replaces the set of fences being watched.
  void updateLocations(List<SavedLocation> locations);

  /// Starts watching. Location permission must already be granted; this
  /// never prompts.
  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}

/// Pure, platform-free decision logic behind [ForegroundGeofenceService].
///
/// GPS fixes jitter by tens of metres, so a naive `distance <= radius`
/// check flaps enter/exit when the user stands near an edge. Three guards:
///
/// 1. Hysteresis: a place is entered at `distance <= radius` but only left
///    once `distance > radius + exitBuffer`, where the buffer is
///    `max(minExitBufferMeters, radius * exitBufferFraction)`.
/// 2. Confirmation: a transition needs [confirmations] consecutive fixes on
///    the far side of the threshold; any contradicting fix resets the count.
/// 3. Accuracy: fixes worse than [maxAccuracyMeters] are ignored.
class GeofenceEvaluator {
  GeofenceEvaluator({
    this.minExitBufferMeters = 25,
    this.exitBufferFraction = 0.2,
    this.confirmations = 2,
    this.maxAccuracyMeters = 100,
  }) : assert(confirmations >= 1);

  final double minExitBufferMeters;
  final double exitBufferFraction;
  final int confirmations;
  final double maxAccuracyMeters;

  final Map<String, _FenceState> _states = {};

  Set<String> get insideIds => {
    for (final e in _states.entries)
      if (e.value.inside) e.key,
  };

  /// Forgets all state (e.g. when tracking is stopped).
  void reset() => _states.clear();

  double exitBufferFor(double radiusMeters) {
    final proportional = radiusMeters * exitBufferFraction;
    return proportional > minExitBufferMeters
        ? proportional
        : minExitBufferMeters;
  }

  /// Feeds one fix; returns the transitions it confirmed (usually none).
  List<GeofenceEvent> evaluate(
    GeoPosition position,
    List<SavedLocation> locations,
  ) {
    // Locations that were deleted must not leave stale "inside" state.
    final ids = {for (final l in locations) l.id};
    _states.removeWhere((id, _) => !ids.contains(id));

    if (position.accuracyMeters > maxAccuracyMeters) return const [];

    final events = <GeofenceEvent>[];
    for (final location in locations) {
      final state = _states.putIfAbsent(location.id, _FenceState.new);
      final distance = position.distanceTo(
        location.latitude,
        location.longitude,
      );

      final bool wantsFlip = state.inside
          ? distance >
                location.radiusMeters + exitBufferFor(location.radiusMeters)
          : distance <= location.radiusMeters;

      if (!wantsFlip) {
        state.streak = 0;
        continue;
      }
      state.streak++;
      if (state.streak < confirmations) continue;

      state.streak = 0;
      state.inside = !state.inside;
      events.add(
        GeofenceEvent(
          location: location,
          transition: state.inside
              ? GeofenceTransition.enter
              : GeofenceTransition.exit,
          distanceMeters: distance,
          timestamp: position.timestamp,
        ),
      );
    }
    return events;
  }
}

class _FenceState {
  bool inside = false;
  int streak = 0;
}

/// [GeofenceService] driven by the foreground position stream. See the
/// limitation notes on [GeofenceService].
class ForegroundGeofenceService implements GeofenceService {
  ForegroundGeofenceService({
    required LocationService locationService,
    GeofenceEvaluator? evaluator,
    this.distanceFilterMeters = 15,
  }) : _location = locationService,
       _evaluator = evaluator ?? GeofenceEvaluator();

  final LocationService _location;
  final GeofenceEvaluator _evaluator;
  final int distanceFilterMeters;

  final _controller = StreamController<GeofenceEvent>.broadcast();
  StreamSubscription<GeoPosition>? _subscription;
  List<SavedLocation> _locations = const [];

  @override
  Stream<GeofenceEvent> get events => _controller.stream;

  @override
  Set<String> get insideLocationIds => _evaluator.insideIds;

  @override
  bool get isRunning => _subscription != null;

  @override
  void updateLocations(List<SavedLocation> locations) {
    _locations = List.unmodifiable(locations);
  }

  @override
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _location
        .positionStream(distanceFilterMeters: distanceFilterMeters)
        .listen(onPosition, onError: (_) => stop(), cancelOnError: false);
  }

  /// Exposed for tests and for callers that already receive fixes (the map
  /// screen) and want to avoid a second GPS subscription.
  void onPosition(GeoPosition position) {
    if (_controller.isClosed) return;
    for (final event in _evaluator.evaluate(position, _locations)) {
      _controller.add(event);
    }
  }

  @override
  Future<void> stop() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    _evaluator.reset();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
