// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:get/get.dart';

import '../../core/services/location/geofence_service.dart';
import '../../core/services/location/location_service.dart';
import '../../core/utils/geo.dart';
import '../../domain/entities/saved_location.dart';
import '../../domain/repositories/saved_location_repository.dart';
import 'auth_controller.dart';
import 'calendar_controller.dart';
import 'task_controller.dart';

/// Something a saved place can be linked to (a task or calendar event).
class LocationLinkOption {
  const LocationLinkOption({
    required this.id,
    required this.label,
    required this.isTask,
  });
  final String id;
  final String label;
  final bool isTask;
}

/// State for the map screen: permission, current position, saved places,
/// distances and the foreground geofence toggle.
///
/// Location permission is requested ONLY from [enableLocation] (a user
/// tap). [onInit] merely checks the current state, which never prompts.
class PlacesController extends GetxController {
  PlacesController({
    required LocationService locationService,
    required SavedLocationRepository repository,
    required GeofenceService geofenceService,
    String? Function()? userIdProvider,
    List<LocationLinkOption> Function()? linkOptionsProvider,
    String Function()? idGenerator,
    DateTime Function()? clock,
  }) : _location = locationService,
       _repository = repository,
       _geofence = geofenceService,
       _userId = userIdProvider ?? _defaultUserId,
       _linkOptions = linkOptionsProvider ?? _defaultLinkOptions,
       _newId = idGenerator ?? _defaultId,
       _now = clock ?? DateTime.now;

  final LocationService _location;
  final SavedLocationRepository _repository;
  final GeofenceService _geofence;
  final String? Function() _userId;
  final List<LocationLinkOption> Function() _linkOptions;
  final String Function() _newId;
  final DateTime Function() _now;

  /// null until the first non-prompting check completes.
  final access = Rxn<LocationAccess>();
  final position = Rxn<GeoPosition>();
  final locations = <SavedLocation>[].obs;
  final isLoading = true.obs;
  final isLocating = false.obs;
  final loadError = RxnString();
  final geofenceEnabled = false.obs;
  final insideIds = <String>{}.obs;

  /// One-shot confirmation / problem text for the page to show.
  final notice = RxnString();
  final recentEvents = <GeofenceEvent>[].obs;

  StreamSubscription<GeoPosition>? _positionSub;
  StreamSubscription<GeofenceEvent>? _geofenceSub;

  /// Stream of geofence events, for the notification layer later.
  Stream<GeofenceEvent> get geofenceEvents => _geofence.events;

  bool get hasAccess => access.value == LocationAccess.granted;

  List<LocationLinkOption> get linkOptions => _linkOptions();

  @override
  void onInit() {
    super.onInit();
    _geofenceSub = _geofence.events.listen(_onGeofenceEvent);
    unawaited(load());
  }

  @override
  void onClose() {
    _positionSub?.cancel();
    _geofenceSub?.cancel();
    unawaited(_geofence.stop());
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = null;
    final uid = _userId();
    try {
      if (uid != null) {
        locations.assignAll(await _repository.getLocations(uid));
        _geofence.updateLocations(locations);
        // Best effort background merge + retry of pending pushes.
        unawaited(_syncInBackground(uid));
      }
    } catch (e) {
      loadError.value = 'Could not load your saved places.';
    }
    access.value = await _location.checkAccess();
    isLoading.value = false;
    if (hasAccess) await _refreshPosition(startWatching: true);
  }

  Future<void> _syncInBackground(String uid) async {
    try {
      await _repository.syncPending(uid);
      final merged = await _repository.refreshFromRemote(uid);
      if (merged.length != locations.length ||
          !merged.every(locations.contains)) {
        locations.assignAll(merged);
        _geofence.updateLocations(locations);
      }
    } catch (_) {}
  }

  /// User tapped "Use my location" / the locate button. The only place a
  /// permission prompt can originate.
  Future<void> enableLocation() async {
    isLocating.value = true;
    try {
      final result = await _location.requestAccess();
      access.value = result;
      if (result == LocationAccess.granted) {
        await _refreshPosition(startWatching: true);
      }
    } finally {
      isLocating.value = false;
    }
  }

  Future<void> _refreshPosition({required bool startWatching}) async {
    try {
      position.value = await _location.currentPosition();
    } on LocationUnavailableException catch (e) {
      notice.value = e.message;
    } catch (_) {
      notice.value = 'Could not read your location.';
    }
    if (startWatching) _watch();
  }

  void _watch() {
    if (_positionSub != null) return;
    _positionSub = _location.positionStream().listen(
      (p) => position.value = p,
      onError: (_) {
        _positionSub?.cancel();
        _positionSub = null;
      },
    );
  }

  /// Opens the right system screen for the current problem.
  Future<void> openSettings() async {
    final opened = access.value == LocationAccess.serviceDisabled
        ? await _location.openLocationSettings()
        : await _location.openAppSettings();
    if (!opened) {
      notice.value =
          'Could not open settings. Change location access in your '
          'browser or system settings.';
    }
  }

  /// After returning from settings.
  Future<void> recheckAccess() async {
    access.value = await _location.checkAccess();
    if (hasAccess) await _refreshPosition(startWatching: true);
  }

  // --- Saved places -----------------------------------------------------

  Future<SavedLocation?> saveLocation({
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = SavedLocation.defaultRadiusMeters,
    String? linkedEventId,
    String? linkedTaskId,
  }) async {
    final uid = _userId();
    final trimmed = name.trim();
    if (uid == null) {
      notice.value = 'Sign in to save places.';
      return null;
    }
    if (trimmed.isEmpty) {
      notice.value = 'Give the place a name.';
      return null;
    }
    final radius = radiusMeters.clamp(
      SavedLocation.minRadiusMeters,
      SavedLocation.maxRadiusMeters,
    );
    final now = _now();
    final place = SavedLocation(
      id: _newId(),
      userId: uid,
      name: trimmed,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radius.toDouble(),
      linkedEventId: linkedEventId,
      linkedTaskId: linkedTaskId,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _repository.save(place);
    } catch (e) {
      notice.value = 'Could not save "$trimmed". Try again.';
      return null;
    }
    locations.add(place);
    _geofence.updateLocations(locations);
    notice.value = 'Saved "$trimmed"';
    return place;
  }

  Future<void> updateLocation(
    SavedLocation place, {
    String? name,
    double? radiusMeters,
    String? linkedEventId,
    String? linkedTaskId,
    bool clearLinks = false,
  }) async {
    final updated = place.copyWith(
      name: name?.trim().isEmpty ?? true ? null : name!.trim(),
      radiusMeters: radiusMeters?.clamp(
        SavedLocation.minRadiusMeters,
        SavedLocation.maxRadiusMeters,
      ),
      linkedEventId: linkedEventId,
      linkedTaskId: linkedTaskId,
      clearLinkedEvent: clearLinks,
      clearLinkedTask: clearLinks,
      updatedAt: _now(),
    );
    try {
      await _repository.save(updated);
    } catch (_) {
      notice.value = 'Could not update "${place.name}".';
      return;
    }
    final i = locations.indexWhere((l) => l.id == place.id);
    if (i >= 0) locations[i] = updated;
    _geofence.updateLocations(locations);
    notice.value = 'Updated "${updated.name}"';
  }

  Future<void> deleteLocation(SavedLocation place) async {
    try {
      await _repository.delete(place.userId, place.id);
    } catch (_) {
      notice.value = 'Could not delete "${place.name}".';
      return;
    }
    locations.removeWhere((l) => l.id == place.id);
    insideIds.remove(place.id);
    _geofence.updateLocations(locations);
    notice.value = 'Deleted "${place.name}"';
  }

  // --- Distances --------------------------------------------------------

  double? distanceTo(SavedLocation place) {
    final p = position.value;
    return p?.distanceTo(place.latitude, place.longitude);
  }

  /// The closest saved place the user is not already inside, or the closest
  /// overall when inside all of them. Null without a position or places.
  SavedLocation? get nextPlace {
    final p = position.value;
    if (p == null || locations.isEmpty) return null;
    SavedLocation? best;
    var bestDistance = double.infinity;
    SavedLocation? bestAny;
    var bestAnyDistance = double.infinity;
    for (final l in locations) {
      final d = p.distanceTo(l.latitude, l.longitude);
      if (d < bestAnyDistance) {
        bestAny = l;
        bestAnyDistance = d;
      }
      if (d > l.radiusMeters && d < bestDistance) {
        best = l;
        bestDistance = d;
      }
    }
    return best ?? bestAny;
  }

  String? distanceLabelTo(SavedLocation place) {
    final d = distanceTo(place);
    return d == null ? null : formatDistance(d);
  }

  // --- Geofencing -------------------------------------------------------

  /// Foreground-only geofencing (see [GeofenceService] docs).
  Future<void> setGeofencing(bool enabled) async {
    if (!enabled) {
      await _geofence.stop();
      geofenceEnabled.value = false;
      insideIds.clear();
      return;
    }
    if (!hasAccess) {
      await enableLocation();
      if (!hasAccess) return;
    }
    if (locations.isEmpty) {
      notice.value = 'Save a place first, then turn on alerts.';
      return;
    }
    _geofence.updateLocations(locations);
    await _geofence.start();
    geofenceEnabled.value = true;
    notice.value = 'Alerts on while the app is open';
  }

  void _onGeofenceEvent(GeofenceEvent e) {
    insideIds.assignAll(_geofence.insideLocationIds);
    recentEvents.insert(0, e);
    if (recentEvents.length > 20) recentEvents.removeLast();
    notice.value = e.isEnter
        ? 'Arrived at ${e.location.name}'
        : 'Left ${e.location.name}';
  }

  static String? _defaultUserId() {
    try {
      return Get.find<AuthController>().currentUser.value?.uid;
    } catch (_) {
      return null;
    }
  }

  static List<LocationLinkOption> _defaultLinkOptions() {
    final options = <LocationLinkOption>[];
    try {
      if (Get.isRegistered<TaskController>()) {
        for (final t in Get.find<TaskController>().tasks) {
          if (!t.completed) {
            options.add(
              LocationLinkOption(id: t.id, label: t.title, isTask: true),
            );
          }
        }
      }
      if (Get.isRegistered<CalendarController>()) {
        for (final e in Get.find<CalendarController>().events) {
          options.add(
            LocationLinkOption(id: e.id, label: e.title, isTask: false),
          );
        }
      }
    } catch (_) {}
    return options;
  }

  static String _defaultId() => 'loc_${DateTime.now().microsecondsSinceEpoch}';
}
