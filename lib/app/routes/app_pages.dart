import 'package:get/get.dart';

import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
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
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardPage()),
    GetPage(name: AppRoutes.tasks, page: () => const TasksPage()),
  ];
}
