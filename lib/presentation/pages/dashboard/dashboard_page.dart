import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/app_section_container.dart';

/// Placeholder dashboard/home shell. Proves the app foundation
/// (theme, routing, GetX) works end-to-end. This is not the real
/// dashboard design — module widgets (Tasks, Calendar, ...) replace the
/// placeholder section below in later phases.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OmniLife'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(
                appController.themeMode.value == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              onPressed: appController.toggleTheme,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: authController.logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AppSectionContainer(
          title: 'Dashboard',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application shell ready. Feature modules '
                '(Tasks, Calendar, Notes, ...) will appear here.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Obx(() {
                final email = authController.currentUser.value?.email;
                return Text(
                  email == null ? 'Signed in' : 'Signed in as $email',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
