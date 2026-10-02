import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_semantic_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../domain/entities/task.dart';
import '../controllers/task_controller.dart';

/// Modal bottom sheet for creating or editing a task.
class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key, this.taskToEdit});

  final Task? taskToEdit;

  static Future<void> show(BuildContext context, {Task? taskToEdit}) {
    return showModalBottomSheet(
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

    final controller = Get.find<TaskController>();

    if (widget.taskToEdit != null) {
      final updated = widget.taskToEdit!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        updatedAt: DateTime.now(),
      );
      await controller.updateTask(updated);
    } else {
      await controller.createTask(
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.taskToEdit != null;

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      constraints: const BoxConstraints(maxWidth: 540),
      margin: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: bottomInset + AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Task' : 'New Task',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Title Field
              TextFormField(
                controller: _titleController,
                autofocus: true,
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
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add details, notes or links',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Priority Selector
              Text(
                'Priority',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
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
                      chipColor = AppColors.primary;
                      break;
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            p.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : chipColor,
                            ),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: chipColor,
                        backgroundColor: chipColor.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.3),
                        ),
                        onSelected: (_) => setState(() => _priority = p),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Due Date Selector
              Text(
                'Due Date',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _dueDate == null
                          ? 'Select date'
                          : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear date',
                      onPressed: () => setState(() => _dueDate = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Create Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
