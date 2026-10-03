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
  ];
}
