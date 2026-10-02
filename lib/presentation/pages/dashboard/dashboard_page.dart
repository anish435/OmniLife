import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/task_controller.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/app_section_container.dart';
import '../../widgets/create_task_sheet.dart';
import '../../widgets/task_card.dart';

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

class _ModuleEntry {
  const _ModuleEntry(this.label, this.icon, {this.route});
  final String label;
  final IconData icon;
  final String? route;
}

const _upcomingModules = [
  _ModuleEntry('Tasks & Projects', Icons.check_box_outlined, route: AppRoutes.tasks),
  _ModuleEntry('Calendar', Icons.calendar_today_outlined),
  _ModuleEntry('Notes', Icons.notes_outlined),
  _ModuleEntry('Habits & Goals', Icons.track_changes_outlined),
  _ModuleEntry('Finance', Icons.account_balance_wallet_outlined),
  _ModuleEntry('Wellness', Icons.self_improvement_outlined),
];

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final authController = Get.find<AuthController>();
    final taskController = Get.find<TaskController>();

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => CreateTaskSheet.show(context),
        tooltip: 'Quick add task',
        child: const Icon(Icons.add),
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
                final user = authController.currentUser.value;
                final name = user?.displayName ?? user?.email ?? 'User';
                return Text(
                  'Welcome, $name',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }),
              const SizedBox(height: AppSpacing.lg),

              // Today's Tasks Section (Live)
              Obx(() {
                final todayTasks = taskController.todayTasks;
                final total = taskController.totalTodayCount;
                final completed = taskController.completedTodayCount;
                final progress = taskController.completionRate;

                return AppSectionContainer(
                  title: 'Today',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (todayTasks.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completed of $total completed',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: progress == 1.0
                                    ? context.semanticColors.success
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final task in todayTasks.take(4))
                          TaskCard(
                            key: ValueKey(task.id),
                            task: task,
                            onToggle: () => taskController.toggleTask(task.id),
                            onDelete: () => taskController.deleteTask(task.id),
                            onTap: () => CreateTaskSheet.show(context, taskToEdit: task),
                          ),
                        TextButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.tasks),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text('View all (${taskController.tasks.length}) tasks'),
                        ),
                      ] else ...[
                        AppEmptyView(
                          message: 'No tasks scheduled for today',
                          subtitle: 'Plan ahead or add a task to get started.',
                          icon: Icons.check_box_outlined,
                          actionLabel: '+ Add Task',
                          onAction: () => CreateTaskSheet.show(context),
                        ),
                      ],
                    ],
                  ),
                );
              }),
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

              // Modules List
              AppSectionContainer(
                title: 'Modules',
                child: Column(
                  children: [
                    for (final module in _upcomingModules)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          module.icon,
                          color: module.route != null
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          module.label,
                          style: TextStyle(
                            fontWeight: module.route != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: module.route != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : Text(
                                'Soon',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                        onTap: module.route != null
                            ? () => Get.toNamed(module.route!)
                            : null,
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
