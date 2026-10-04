import 'package:get/get.dart';

import '../../data/repositories/calendar_repository_impl.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../presentation/controllers/calendar_controller.dart';
import '../../presentation/controllers/task_controller.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
import '../../presentation/pages/calendar/calendar_page.dart';
import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/splash/splash_page.dart';
import '../../presentation/pages/tasks/tasks_page.dart';
import '../../presentation/pages/notes/notes_page.dart';
import '../../presentation/controllers/notes_controller.dart';
import '../../domain/repositories/note_repository.dart';
import '../../data/repositories/note_repository_impl.dart';
import '../../presentation/pages/habits/habits_page.dart';
import '../../presentation/controllers/habits_controller.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../presentation/pages/finance/finance_page.dart';
import '../../presentation/controllers/finance_controller.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../presentation/pages/wellness/wellness_page.dart';
import '../../presentation/controllers/wellness_controller.dart';
import '../../domain/repositories/wellness_repository.dart';
import '../../data/repositories/wellness_repository_impl.dart';
import '../../data/datasources/local/local_wellness_data_source.dart';
import '../../data/datasources/remote/user_scoped_firestore_datasource.dart';
import 'app_routes.dart';

/// Centralized route table. Each future feature adds one [GetPage] entry
/// here rather than screens wiring up their own navigation.
class AppPages {
  static const initial = AppRoutes.splash;

  static final routes = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.register, page: () => const RegisterPage()),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardPage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TaskRepository>()) {
          Get.lazyPut<TaskRepository>(() => TaskRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<TaskController>()) {
          Get.put(TaskController(), permanent: true);
        }
        if (!Get.isRegistered<CalendarRepository>()) {
          Get.lazyPut<CalendarRepository>(() => CalendarRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<CalendarController>()) {
          Get.put(CalendarController(), permanent: true);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.tasks,
      page: () => const TasksPage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TaskRepository>()) {
          Get.lazyPut<TaskRepository>(() => TaskRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<TaskController>()) {
          Get.put(TaskController(), permanent: true);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.calendar,
      page: () => const CalendarPage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<TaskRepository>()) {
          Get.lazyPut<TaskRepository>(() => TaskRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<TaskController>()) {
          Get.put(TaskController(), permanent: true);
        }
        if (!Get.isRegistered<CalendarRepository>()) {
          Get.lazyPut<CalendarRepository>(() => CalendarRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<CalendarController>()) {
          Get.put(CalendarController(), permanent: true);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.notes,
      page: () => const NotesPage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<NoteRepository>()) {
          Get.lazyPut<NoteRepository>(() => NoteRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<NotesController>()) {
          Get.put(NotesController(), permanent: true);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.habits,
      page: () => HabitsPage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<HabitRepository>()) {
          Get.lazyPut<HabitRepository>(() => HabitRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<HabitsController>()) {
          Get.put(HabitsController(), permanent: true);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.finance,
      page: () => const FinancePage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<FinanceRepository>()) {
          Get.lazyPut<FinanceRepository>(() => FinanceRepositoryImpl(), fenix: true);
        }
        if (!Get.isRegistered<FinanceController>()) {
          Get.put(FinanceController(), permanent: true);
        }
      }),
    ),
    GetPage(
      name: AppRoutes.wellness,
      page: () => const WellnessPage(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<WellnessRepository>()) {
          Get.lazyPut<WellnessRepository>(
            () => WellnessRepositoryImpl(
              LocalWellnessDataSource(),
              UserScopedFirestoreDataSource(),
            ),
            fenix: true,
          );
        }
        if (!Get.isRegistered<WellnessController>()) {
          Get.put(WellnessController(), permanent: true);
        }
      }),
    ),
  ];
}
