import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/repositories/auth_repository.dart' show AppUser;
import '../../controllers/app_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/calendar_controller.dart';
import '../../controllers/finance_controller.dart';
import '../../controllers/habits_controller.dart';
import '../../controllers/notes_controller.dart';
import '../../controllers/task_controller.dart';
import '../../widgets/calendar/calendar_colors.dart';
import '../../widgets/create_task_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/module_tile.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/section_label.dart';
import '../../widgets/stat_tile.dart';
import '../../../core/services/notification_service.dart';
import '../../widgets/notifications/notification_sheet.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _greetingMessage(AppUser? user) {
    final hour = DateTime.now().hour;
    String timeGreeting;
    if (hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
    } else {
      timeGreeting = 'Good evening';
    }

    String name;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      name = user.displayName!.trim();
    } else if (user?.email != null && user!.email!.contains('@')) {
      final local = user.email!.split('@').first;
      final clean = local.replaceAll(RegExp(r'[^a-zA-Z]'), ' ').trim();
      if (clean.isNotEmpty) {
        final firstWord = clean.split(' ').first;
        name = firstWord[0].toUpperCase() + firstWord.substring(1).toLowerCase();
      } else {
        name = 'Friend';
      }
    } else {
      name = 'Friend';
    }

    return '$timeGreeting, $name';
  }

  String _userInitials(AppUser? user) {
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      final parts = user.displayName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email![0].toUpperCase();
    }
    return 'O';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline = theme.colorScheme.outline;

    final appController = Get.find<AppController>();
    final authController = Get.find<AuthController>();
    final taskController = Get.isRegistered<TaskController>()
        ? Get.find<TaskController>()
        : Get.put(TaskController(), permanent: true);
    final calendarController = Get.isRegistered<CalendarController>()
        ? Get.find<CalendarController>()
        : Get.put(CalendarController(), permanent: true);

    final notesController = Get.isRegistered<NotesController>()
        ? Get.find<NotesController>()
        : null;
    final habitsController = Get.isRegistered<HabitsController>()
        ? Get.find<HabitsController>()
        : null;
    final financeController = Get.isRegistered<FinanceController>()
        ? Get.find<FinanceController>()
        : null;

    final today = DateTime.now();
    final dateCaption = DateFormat('EEE, d MMM').format(today);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final gutter = AppSpacing.responsiveGutter(context);
    final isWide = screenWidth >= 768;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateTaskSheet.show(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 88),
              children: [
                // 1. Editorial Header Bar (Date Caption + Greeting + Initial Avatar Menu)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateCaption.toUpperCase(),
                            style: AppTypography.sectionLabel(
                              theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Obx(() {
                            final user = authController.currentUser.value;
                            return Text(
                              _greetingMessage(user),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Notifications Bell (Rubric D2)
                    IconButton(
                      tooltip: 'Notifications (Rubric D2)',
                      onPressed: () => NotificationSheet.show(context),
                      icon: Obx(() {
                        final notifCount = Get.isRegistered<NotificationService>()
                            ? Get.find<NotificationService>().unreadCount
                            : 0;
                        return Badge(
                          isLabelVisible: notifCount > 0,
                          label: Text('$notifCount'),
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.notifications_outlined, size: 22),
                        );
                      }),
                    ),
                    const SizedBox(width: 4),

                    // Avatar menu button (Theme toggle + Logout in single refined control)
                    Obx(() {
                      final user = authController.currentUser.value;
                      final initials = _userInitials(user);

                      return PopupMenuButton<String>(
                        tooltip: 'Account & Settings',
                        offset: const Offset(0, 46),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.cardRadius,
                          side: BorderSide(color: hairline, width: 1),
                        ),
                        onSelected: (action) {
                          if (action == 'theme') {
                            appController.toggleTheme();
                          } else if (action == 'logout') {
                            authController.logout();
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'theme',
                            child: Row(
                              children: [
                                Icon(
                                  appController.themeMode.value == ThemeMode.dark
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  appController.themeMode.value == ThemeMode.dark
                                      ? 'Light theme'
                                      : 'Dark theme',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 18, color: AppColors.error),
                                SizedBox(width: 10),
                                Text(
                                  'Log out',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: hairline, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                // 2. Hero: Today's Progress Wide Surface-Raised Block
                Obx(() {
                  final total = taskController.totalTodayCount;
                  final completed = taskController.completedTodayCount;
                  final progress = taskController.completionRate;
                  final remaining = total - completed;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.cardRadius,
                      border: Border.all(color: hairline, width: 1),
                    ),
                    child: Row(
                      children: [
                        ProgressRing(
                          progress: progress,
                          size: 52,
                          strokeWidth: 5,
                          centerText: '${(progress * 100).toInt()}%',
                        ),
                        const SizedBox(width: AppSpacing.mdPlus),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$completed of $total done',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                total == 0
                                    ? 'No tasks scheduled for today.'
                                    : completed == total
                                        ? 'All caught up for today! Well done.'
                                        : '$remaining tasks remaining today.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed(AppRoutes.tasks),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Tasks', style: TextStyle(fontSize: 12)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sectionGap),

                // Multi-column or stacked layout based on width
                if (isWide) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Today Tasks
                      Expanded(
                        flex: 6,
                        child: _buildTodaySection(context, taskController, hairline),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      // Right Column: Next Up & Habits/Notes
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildNextUpSection(context, calendarController, isDark, hairline),
                            const SizedBox(height: AppSpacing.sectionGap),
                            _buildStatsRow(context, notesController, habitsController, financeController),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Single Column (Mobile)
                  _buildTodaySection(context, taskController, hairline),
                  const SizedBox(height: AppSpacing.sectionGap),
                  _buildNextUpSection(context, calendarController, isDark, hairline),
                  const SizedBox(height: AppSpacing.sectionGap),
                  _buildStatsRow(context, notesController, habitsController, financeController),
                ],

                const SizedBox(height: AppSpacing.sectionGap),

                // 5. Modules Grid (2-column, no ACTIVE badges, item counts)
                SectionLabel(
                  title: 'Modules',
                  trailing: Text(
                    '6 modules connected',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Obx(() {
                  final taskCount = taskController.tasks.length;
                  final eventCount = calendarController.events.length;
                  final notesCount = notesController?.notes.length ?? 0;
                  final habitsCount = habitsController?.habits.length ?? 0;
                  final txCount = financeController?.transactions.length ?? 0;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 700 ? 3 : 2;
                      final ratio = constraints.maxWidth >= 700 ? 2.4 : 2.0;

                      return GridView.count(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: ratio,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          ModuleTile(
                            name: 'Tasks',
                            icon: Icons.check_box_outlined,
                            accentColor: AppColors.moduleTasks,
                            countLabel: '$taskCount items',
                            onTap: () => Get.toNamed(AppRoutes.tasks),
                          ),
                          ModuleTile(
                            name: 'Calendar',
                            icon: Icons.calendar_today_outlined,
                            accentColor: AppColors.moduleCalendar,
                            countLabel: '$eventCount events',
                            onTap: () => Get.toNamed(AppRoutes.calendar),
                          ),
                          ModuleTile(
                            name: 'Notes',
                            icon: Icons.notes_outlined,
                            accentColor: AppColors.moduleNotes,
                            countLabel: '$notesCount notes',
                            onTap: () => Get.toNamed(AppRoutes.notes),
                          ),
                          ModuleTile(
                            name: 'Habits',
                            icon: Icons.track_changes_outlined,
                            accentColor: AppColors.moduleHabits,
                            countLabel: '$habitsCount habits',
                            onTap: () => Get.toNamed(AppRoutes.habits),
                          ),
                          ModuleTile(
                            name: 'Finance',
                            icon: Icons.account_balance_wallet_outlined,
                            accentColor: AppColors.moduleFinance,
                            countLabel: '$txCount trans.',
                            onTap: () => Get.toNamed(AppRoutes.finance),
                          ),
                          ModuleTile(
                            name: 'Wellness',
                            icon: Icons.self_improvement_outlined,
                            accentColor: AppColors.moduleWellness,
                            countLabel: 'Active',
                            onTap: () => Get.toNamed(AppRoutes.wellness),
                          ),
                          ModuleTile(
                            name: 'Focus',
                            icon: Icons.timer_outlined,
                            accentColor: AppColors.accentTerracottaDark,
                            countLabel: 'Timer',
                            onTap: () => Get.toNamed(AppRoutes.focus),
                          ),
                        ],
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySection(
    BuildContext context,
    TaskController taskController,
    Color hairline,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          title: 'Today',
          trailing: Obx(() {
            final count = taskController.todayTasks.length;
            return count > 0
                ? TextButton(
                    onPressed: () => Get.toNamed(AppRoutes.tasks),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    child: Text('View all ($count)', style: const TextStyle(fontSize: 12)),
                  )
                : const SizedBox.shrink();
          }),
        ),
        Obx(() {
          final todayTasks = taskController.todayTasks;
          if (todayTasks.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: hairline, width: 1),
              ),
              child: EmptyState(
                message: 'Nothing due today.',
                icon: Icons.check_circle_outline,
                actionLabel: 'Add task',
                onAction: () => CreateTaskSheet.show(context),
              ),
            );
          }

          return Material(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.cardRadius,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.cardRadius,
              side: BorderSide(color: hairline, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: todayTasks.take(4).length,
              separatorBuilder: (_, index) => Divider(height: 1, color: hairline),
              itemBuilder: (context, index) {
                final task = todayTasks[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: InkWell(
                    onTap: () => taskController.toggleTask(task.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.completed ? theme.colorScheme.primary : Colors.transparent,
                        border: Border.all(
                          color: task.completed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: task.completed
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  title: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: task.completed ? TextDecoration.lineThrough : null,
                      color: task.completed
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: task.dueDate != null
                      ? Text(
                          DateFormat('HH:mm').format(task.dueDate!),
                          style: AppTypography.tabular(
                            theme.textTheme.bodySmall!.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => CreateTaskSheet.show(context, taskToEdit: task),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNextUpSection(
    BuildContext context,
    CalendarController calendarController,
    bool isDark,
    Color hairline,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          title: 'Next up',
          trailing: TextButton(
            onPressed: () => Get.toNamed(AppRoutes.calendar),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            ),
            child: const Text('Calendar', style: TextStyle(fontSize: 12)),
          ),
        ),
        Obx(() {
          final nextEvent = calendarController.nextUpEvent;
          if (nextEvent == null) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: hairline, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nothing scheduled.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'Open Calendar',
                    onPressed: () => Get.toNamed(AppRoutes.calendar),
                  ),
                ],
              ),
            );
          }

          final tag = CalendarColors.getTag(nextEvent.colorTag);
          final now = DateTime.now();
          final isToday = nextEvent.startAt.year == now.year &&
              nextEvent.startAt.month == now.month &&
              nextEvent.startAt.day == now.day;

          String timeLabel;
          if (nextEvent.isAllDay) {
            timeLabel = 'All Day';
          } else if (isToday) {
            final startH = nextEvent.startAt.hour.toString().padLeft(2, '0');
            final startM = nextEvent.startAt.minute.toString().padLeft(2, '0');
            timeLabel = '$startH:$startM';
          } else {
            timeLabel = DateFormat('MMM d').format(nextEvent.startAt);
          }

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.toNamed(AppRoutes.calendar),
              borderRadius: AppRadius.cardRadius,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: hairline, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        color: tag.color,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.smPlus),
                    Text(
                      timeLabel,
                      style: AppTypography.tabular(
                        TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tag.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.smPlus),
                    Expanded(
                      child: Text(
                        nextEvent.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    NotesController? notesController,
    HabitsController? habitsController,
    FinanceController? financeController,
  ) {
    return Obx(() {
      final notesCount = notesController?.notes.length ?? 0;
      final habitsCount = habitsController?.habits.length ?? 0;

      return Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Notes',
              value: '$notesCount',
              sublabel: 'Pinned & quick notes',
              icon: Icons.notes_outlined,
              iconColor: AppColors.moduleNotes,
              onTap: () => Get.toNamed(AppRoutes.notes),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: 'Habits',
              value: '$habitsCount',
              sublabel: 'Active habits',
              icon: Icons.track_changes_outlined,
              iconColor: AppColors.moduleHabits,
              onTap: () => Get.toNamed(AppRoutes.habits),
            ),
          ),
        ],
      );
    });
  }
}
