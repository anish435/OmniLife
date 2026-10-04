import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/calendar_controller.dart';
import '../../controllers/task_controller.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/app_section_container.dart';
import '../../widgets/calendar/calendar_colors.dart';
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
  _ModuleEntry('Calendar', Icons.calendar_today_outlined, route: AppRoutes.calendar),
  _ModuleEntry('Notes', Icons.notes_outlined, route: AppRoutes.notes),
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
    final taskController = Get.isRegistered<TaskController>()
        ? Get.find<TaskController>()
        : Get.put(TaskController(), permanent: true);
    final calendarController = Get.isRegistered<CalendarController>()
        ? Get.find<CalendarController>()
        : Get.put(CalendarController(), permanent: true);

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

              // Next Up Section (Live Calendar)
              Obx(() {
                final nextEvent = calendarController.nextUpEvent;
                if (nextEvent == null) {
                  return AppSectionContainer(
                    title: 'Next up',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nothing scheduled.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed(AppRoutes.calendar),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Open Calendar',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }

                final tag = CalendarColors.getTag(nextEvent.colorTag);
                final isDark = Theme.of(context).brightness == Brightness.dark;

                final now = DateTime.now();
                final isToday = nextEvent.startAt.year == now.year &&
                    nextEvent.startAt.month == now.month &&
                    nextEvent.startAt.day == now.day;

                String timeLabel;
                if (isToday) {
                  if (nextEvent.isAllDay) {
                    timeLabel = 'All Day';
                  } else {
                    final startH = nextEvent.startAt.hour.toString().padLeft(2, '0');
                    final startM = nextEvent.startAt.minute.toString().padLeft(2, '0');
                    timeLabel = '$startH:$startM';
                  }
                } else {
                  final monthShort = _monthNames[nextEvent.startAt.month - 1].substring(0, 3);
                  timeLabel = '${nextEvent.startAt.day} $monthShort';
                }

                return AppSectionContainer(
                  title: 'Next up',
                  child: InkWell(
                    onTap: () => Get.toNamed(AppRoutes.calendar),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: tag.background(isDark),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: tag.border(isDark), width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          Container(width: 4, color: tag.color),
                          const SizedBox(width: 10),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tag.color,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              nextEvent.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tag.color,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward,
                              size: 14,
                              color: tag.color.withValues(alpha: 0.7)),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
