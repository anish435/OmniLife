import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/task.dart';
import '../../controllers/task_controller.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/create_task_sheet.dart';
import '../../widgets/task_card.dart';

/// Full-featured Task & Project management screen.
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final TaskController _taskController;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _taskController = Get.isRegistered<TaskController>()
        ? Get.find<TaskController>()
        : Get.put(TaskController(), permanent: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  border: InputBorder.none,
                  filled: false,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _taskController.setSearch('');
                      setState(() => _showSearch = false);
                    },
                  ),
                ),
                onChanged: _taskController.setSearch,
              )
            : const Text('Tasks & Projects'),
        actions: [
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search tasks',
              onPressed: () => setState(() => _showSearch = true),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh tasks',
            onPressed: () => _taskController.loadTasks(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateTaskSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Filter Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                  AppSpacing.screenPadding,
                  AppSpacing.xs,
                ),
                child: Obx(() {
                  final activeFilter = _taskController.selectedFilter.value;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: TaskFilter.values.map((filter) {
                        final isSelected = activeFilter == filter;
                        String label;
                        switch (filter) {
                          case TaskFilter.all:
                            label = 'All (${_taskController.tasks.length})';
                            break;
                          case TaskFilter.today:
                            label = 'Today (${_taskController.todayTasks.length})';
                            break;
                          case TaskFilter.upcoming:
                            label = 'Upcoming';
                            break;
                          case TaskFilter.completed:
                            label = 'Completed';
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (_) => _taskController.setFilter(filter),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.chipRadius,
                            ),
                            backgroundColor: isDark
                                ? theme.colorScheme.surface
                                : theme.colorScheme.surfaceContainerLowest,
                            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
              ),

              // Priority Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                  vertical: AppSpacing.xs,
                ),
                child: Obx(() {
                  final activePriority = _taskController.selectedPriority.value;

                  return Row(
                    children: [
                      Text(
                        'PRIORITY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _priorityFilterPill(null, 'ANY', activePriority == null),
                      _priorityFilterPill(TaskPriority.high, 'HIGH', activePriority == TaskPriority.high),
                      _priorityFilterPill(TaskPriority.medium, 'MED', activePriority == TaskPriority.medium),
                      _priorityFilterPill(TaskPriority.low, 'LOW', activePriority == TaskPriority.low),
                    ],
                  );
                }),
              ),

              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),

              // Task List Content
              Expanded(
                child: Obx(() {
                  if (_taskController.isLoading.value && _taskController.tasks.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  final filtered = _taskController.filteredTasks;
                  if (filtered.isEmpty) {
                    return AppEmptyView(
                      message: _taskController.searchQuery.value.isNotEmpty
                          ? 'No tasks matching "${_taskController.searchQuery.value}"'
                          : 'No tasks in this view',
                      actionLabel: 'Create Task',
                      onAction: () => CreateTaskSheet.show(context),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.sm,
                      AppSpacing.screenPadding,
                      AppSpacing.section + 48,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final task = filtered[index];
                      return TaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        onToggle: () => _taskController.toggleTask(task.id),
                        onDelete: () => _taskController.deleteTask(task.id),
                        onTap: () => CreateTaskSheet.show(context, taskToEdit: task),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityFilterPill(TaskPriority? priority, String label, bool isSelected) {
    final theme = Theme.of(context);
    Color color;
    switch (priority) {
      case TaskPriority.high:
        color = AppColors.error;
        break;
      case TaskPriority.medium:
        color = context.semanticColors.warning;
        break;
      case TaskPriority.low:
        color = AppColors.primary;
        break;
      case null:
        color = theme.colorScheme.onSurface;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _taskController.setPriority(priority),
        borderRadius: AppRadius.chipRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: AppRadius.chipRadius,
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
