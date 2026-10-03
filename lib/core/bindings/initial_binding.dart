import 'package:get/get.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/calendar_repository_impl.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../presentation/controllers/app_controller.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/controllers/calendar_controller.dart';
import '../../presentation/controllers/task_controller.dart';

/// Registers app-wide dependencies once, at startup.
///
/// Repositories are registered lazily ([Get.lazyPut]) so they are only
/// constructed the first time a feature actually asks for them.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppController(), permanent: true);
    // Must be registered before AuthController, which resolves it eagerly.
    Get.lazyPut<AuthRepository>(() => AuthRepositoryImpl(), fenix: true);
    Get.put(AuthController(), permanent: true);

    Get.lazyPut<TaskRepository>(() => TaskRepositoryImpl(), fenix: true);
    Get.put(TaskController(), permanent: true);

    Get.lazyPut<CalendarRepository>(() => CalendarRepositoryImpl(), fenix: true);
    Get.put(CalendarController(), permanent: true);
  }
}

