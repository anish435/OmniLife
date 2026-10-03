import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/bindings/initial_binding.dart';
import '../presentation/controllers/app_controller.dart';
import 'routes/app_pages.dart';
import 'theme/app_theme.dart';

/// Application root. Wires theme, routing and the GetX dependency
/// foundation together; contains no feature/business logic.
class OmniLifeApp extends StatelessWidget {
  const OmniLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    InitialBinding().dependencies();
    final appController = Get.find<AppController>();

    return Obx(
      () => GetMaterialApp(
        title: 'OmniLife',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: appController.themeMode.value,
        initialBinding: InitialBinding(),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}
