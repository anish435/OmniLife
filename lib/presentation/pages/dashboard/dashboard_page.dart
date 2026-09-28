import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_spacing.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/app_section_container.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// A future module entry shown on the dashboard before its feature
/// exists. Intentionally not a live nav target yet — this is the
/// dashboard's real navigation structure, staged ahead of the modules
/// it will link to.
class _ModuleEntry {
  const _ModuleEntry(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _upcomingModules = [
  _ModuleEntry('Tasks', Icons.check_box_outlined),
  _ModuleEntry('Calendar', Icons.calendar_today_outlined),
  _ModuleEntry('Notes', Icons.notes_outlined),
  _ModuleEntry('Habits', Icons.track_changes_outlined),
  _ModuleEntry('Finance', Icons.account_balance_wallet_outlined),
  _ModuleEntry('Wellness', Icons.self_improvement_outlined),
];

/// Dashboard/home shell. This is a real-shaped productivity dashboard —
/// today/upcoming/habits/notes sections and a module list — but every
/// section is a genuine empty state, since Tasks/Calendar/Notes/Habits
/// are not implemented yet. Nothing here fakes user data; each section
/// is structured so a later phase can swap the empty state for a real
/// repository-backed list.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final authController = Get.find<AuthController>();
    final today = DateTime.now();
    final dateLabel =
        '${_weekdayNames[today.weekday - 1]}, '
        '${today.day} ${_monthNames[today.month - 1]} ${today.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('OmniLife'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(
                appController.themeMode.value == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Text(dateLabel, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Obx(() {
                final email = authController.currentUser.value?.email;
                return Text(
                  email == null ? 'Signed in' : 'Signed in as $email',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }),
              const SizedBox(height: AppSpacing.lg),

              const AppSectionContainer(
                title: 'Today',
                child: AppEmptyView(
                  message: 'No tasks yet',
                  subtitle:
                      'Tasks will appear here once the Tasks module is built.',
                  icon: Icons.check_box_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              const AppSectionContainer(
                title: 'Upcoming',
                child: AppEmptyView(
                  message: 'No upcoming events',
                  subtitle: 'Calendar events will appear here once the Calendar module is built.',
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              const AppSectionContainer(
                title: 'Habits & goals',
                child: AppEmptyView(
                  message: 'No active habits or goals',
                  subtitle: 'This section will track streaks and progress once built.',
                  icon: Icons.track_changes_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              const AppSectionContainer(
                title: 'Notes',
                child: AppEmptyView(
                  message: 'No recent notes',
                  subtitle: 'Recent notes will appear here once the Notes module is built.',
                  icon: Icons.notes_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              AppSectionContainer(
                title: 'Modules',
                child: Column(
                  children: [
                    for (final module in _upcomingModules)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(module.icon),
                        title: Text(module.label),
                        trailing: Text(
                          'Soon',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
