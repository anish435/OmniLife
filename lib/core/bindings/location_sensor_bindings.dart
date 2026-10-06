import 'package:get/get.dart';

import '../../data/repositories/saved_location_repository_impl.dart';
import '../../data/repositories/steps_repository_impl.dart';
import '../../domain/repositories/saved_location_repository.dart';
import '../../domain/repositories/steps_repository.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/controllers/places_controller.dart';
import '../../presentation/controllers/sensors_controller.dart';
import '../services/location/geofence_service.dart';
import '../services/location/geolocator_location_service.dart';
import '../services/location/location_service.dart';
import '../services/sensors/device_sensor_service.dart';
import '../services/sensors/sensor_service.dart';

/// Registers the Maps/GPS and Sensors services and repositories.
///
/// Everything is lazy: nothing is constructed (and no permission is ever
/// requested) until a screen asks for it. Called from `InitialBinding` and
/// again, idempotently, from the route bindings.
void registerLocationSensorServices() {
  if (!Get.isRegistered<LocationService>()) {
    Get.lazyPut<LocationService>(
      () => const GeolocatorLocationService(),
      fenix: true,
    );
  }
  if (!Get.isRegistered<GeofenceService>()) {
    Get.lazyPut<GeofenceService>(
      () => ForegroundGeofenceService(
        locationService: Get.find<LocationService>(),
      ),
      fenix: true,
    );
  }
  if (!Get.isRegistered<SavedLocationRepository>()) {
    Get.lazyPut<SavedLocationRepository>(
      () => SavedLocationRepositoryImpl(),
      fenix: true,
    );
  }
  if (!Get.isRegistered<SensorService>()) {
    Get.lazyPut<SensorService>(() => const DeviceSensorService(), fenix: true);
  }
  if (!Get.isRegistered<StepsRepository>()) {
    Get.lazyPut<StepsRepository>(
      () => StepsRepositoryImpl(
        userIdProvider: () {
          try {
            return Get.find<AuthController>().currentUser.value?.uid;
          } catch (_) {
            return null;
          }
        },
      ),
      fenix: true,
    );
  }
}

/// Route binding for `/map`.
void registerMapDependencies() {
  registerLocationSensorServices();
  if (!Get.isRegistered<PlacesController>()) {
    Get.put(
      PlacesController(
        locationService: Get.find<LocationService>(),
        repository: Get.find<SavedLocationRepository>(),
        geofenceService: Get.find<GeofenceService>(),
      ),
    );
  }
}

/// Route binding for `/sensors`.
void registerSensorDependencies() {
  registerLocationSensorServices();
  if (!Get.isRegistered<SensorsController>()) {
    Get.put(
      SensorsController(
        sensors: Get.find<SensorService>(),
        repository: Get.find<StepsRepository>(),
      ),
    );
  }
}
