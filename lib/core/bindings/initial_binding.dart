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
import '../../presentation/controllers/notes_controller.dart';
import '../../data/repositories/note_repository_impl.dart';
import '../../domain/repositories/note_repository.dart';
import '../../presentation/controllers/habits_controller.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../presentation/controllers/finance_controller.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../presentation/controllers/wellness_controller.dart';
import '../../data/repositories/wellness_repository_impl.dart';
import '../../domain/repositories/wellness_repository.dart';
import '../../data/datasources/local/local_wellness_data_source.dart';
import '../../data/datasources/remote/user_scoped_firestore_datasource.dart';
import '../services/notification_service.dart';
// --- Maps / GPS and Sensors modules (additive) ---
import 'location_sensor_bindings.dart';

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

    Get.lazyPut<NoteRepository>(() => NoteRepositoryImpl(), fenix: true);
    Get.put(NotesController(), permanent: true);

    Get.lazyPut<HabitRepository>(() => HabitRepositoryImpl(), fenix: true);
    Get.put(HabitsController(), permanent: true);

    Get.lazyPut<FinanceRepository>(() => FinanceRepositoryImpl(), fenix: true);
    Get.put(FinanceController(), permanent: true);

    Get.lazyPut<WellnessRepository>(
      () => WellnessRepositoryImpl(
        LocalWellnessDataSource(),
        UserScopedFirestoreDataSource(),
      ),
      fenix: true,
    );
    Get.put(WellnessController(), permanent: true);

    // --- Maps / GPS and Sensors modules (additive; lazy, no permission
    // prompts and no sensor access until the user opens those screens) ---
    registerLocationSensorServices();

    // Notification Service (Rubric D2)
    final notifService = Get.put(NotificationService(), permanent: true);
    notifService.init();
  }
}

