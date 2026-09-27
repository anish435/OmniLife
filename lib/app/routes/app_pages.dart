import 'package:get/get.dart';

import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/splash/splash_page.dart';
import 'app_routes.dart';

/// Centralized route table. Each future feature adds one [GetPage] entry
/// here rather than screens wiring up their own navigation.
class AppPages {
  static const initial = AppRoutes.splash;

  static final routes = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardPage()),
  ];
}
