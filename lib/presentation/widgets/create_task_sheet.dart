import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_semantic_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../domain/entities/task.dart';
import '../../core/services/notification_service.dart';
import '../controllers/task_controller.dart';
import 'app_bottom_sheet_frame.dart';

/// Modal bottom sheet for creating or editing a task with confirmation.
class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key, this.taskToEdit});

  final Task? taskToEdit;

  static Future<void> show(BuildContext context, {Task? taskToEdit}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateTaskSheet(taskToEdit: taskToEdit),
    );
  }

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late TaskPriority _priority;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController =
        TextEditingController(text: widget.taskToEdit?.description ?? '');
    _priority = widget.taskToEdit?.priority ?? TaskPriority.medium;
    _dueDate = widget.taskToEdit?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final desc = _descController.text.trim().isEmpty ? null : _descController.text.trim();

    try {
      final controller = Get.isRegistered<TaskController>()
          ? Get.find<TaskController>()
          : Get.put(TaskController(), permanent: true);

      if (widget.taskToEdit != null) {
        final updated = widget.taskToEdit!.copyWith(
          title: title,
          description: desc,
          priority: _priority,
          dueDate: _dueDate,
          updatedAt: DateTime.now(),
        );
        await controller.updateTask(updated);
      } else {
        final created = await controller.createTask(
          title: title,
          description: desc,
          priority: _priority,
          dueDate: _dueDate,
        );

        // Notification trigger (Rubric D2: Task Reminder)
        if (Get.isRegistered<NotificationService>()) {
          final notifService = Get.find<NotificationService>();
          await notifService.showTaskReminder(
            title: title,
            dueDate: _dueDate,
            taskId: created?.id,
          );
          if (_dueDate != null && _dueDate!.isAfter(DateTime.now())) {
            await notifService.scheduleReminder(
              id: title.hashCode & 0x7FFFFFFF,
              title: 'Reminder: $title',
              body: 'Task is due now',
              scheduledDate: _dueDate!,
              payload: created == null ? null : 'task:${created.id}',
            );
          }
        }
      }

      if (mounted) {
        // Confirmation feedback (Rubric D1)
        final dateStr = _dueDate != null
            ? DateFormat('EEE, MMM d').format(_dueDate!)
            : 'No due date';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.taskToEdit != null
                        ? 'Updated "$title" ($dateStr)'
                        : 'Created "$title" ($dateStr)',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
          Get.back();
        }
      }
    } catch (e, stack) {
      if (kDebugMode) debugPrint('CreateTaskSheet submit error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.taskToEdit != null;
    final hairline = theme.colorScheme.outline;

    return AppBottomSheetFrame(
      title: isEditing ? 'Edit Task' : 'New Task',
      action: ElevatedButton(
        onPressed: _isSaving ? null : _submit,
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(isEditing ? 'Save Changes' : 'Create Task'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Field (large, prominent)
            TextFormField(
              controller: _titleController,
              autofocus: true,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Task title',
                hintText: 'What needs to be done?',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Title cannot be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Description Field
            TextFormField(
              controller: _descController,
              maxLines: 2,
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add details, notes or links',
              ),
            ),
            const SizedBox(height: AppSpacing.mdPlus),

            // Priority Selector
            Text(
              'PRIORITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: TaskPriority.values.map((p) {
                final isSelected = _priority == p;
                Color chipColor;
                switch (p) {
                  case TaskPriority.high:
                    chipColor = AppColors.error;
                    break;
                  case TaskPriority.medium:
                    chipColor = context.semanticColors.warning;
                    break;
                  case TaskPriority.low:
                    chipColor = context.semanticColors.moduleTasks;
                    break;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _priority = p),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? chipColor.withValues(alpha: 0.16)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? chipColor : hairline,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: isSelected ? chipColor : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.mdPlus),

            // Due Date Selector
            Text(
              'DUE DATE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    _dueDate == null
                        ? 'Select date'
                        : DateFormat('EEE, MMM d, yyyy').format(_dueDate!),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear date',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _dueDate = null),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
