import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/habit.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/calendar/calendar_colors.dart';

class CreateHabitSheet extends StatefulWidget {
  const CreateHabitSheet({super.key, this.habitToEdit});

  final Habit? habitToEdit;

  static Future<void> show(BuildContext context, {Habit? habitToEdit}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CreateHabitSheet(habitToEdit: habitToEdit),
    );
  }

  @override
  State<CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends State<CreateHabitSheet> {
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _colorTag = 'default';
  HabitFrequency _frequency = HabitFrequency.daily;
  final Set<int> _days = {};
  int _target = 3;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final h = widget.habitToEdit;
    if (h != null) {
      _titleController.text = h.title;
      _descriptionController.text = h.description;
      _colorTag = h.colorTag;
      _frequency = h.frequency;
      _days.addAll(h.specificDays);
      if (h.frequency == HabitFrequency.weekly) {
        _target = h.targetDaysPerWeek.clamp(1, 7);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the habit a title');
      return;
    }
    if (_frequency == HabitFrequency.specificDays && _days.isEmpty) {
      setState(() => _error = 'Pick at least one day');
      return;
    }

    setState(() {
      _error = null;
      _isSaving = true;
    });
    final controller = Get.find<HabitsController>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final desc = _descriptionController.text.trim();
    final days = (_days.toList()..sort());
    final targetPerWeek = switch (_frequency) {
      HabitFrequency.daily => 7,
      HabitFrequency.specificDays => days.length,
      HabitFrequency.weekly => _target,
    };
    final existing = widget.habitToEdit;

    bool ok;
    if (existing != null) {
      ok = await controller.updateHabit(
        existing.copyWith(
          title: title,
          description: desc,
          colorTag: _colorTag,
          frequency: _frequency,
          specificDays: _frequency == HabitFrequency.specificDays
              ? days
              : const [],
          targetDaysPerWeek: targetPerWeek,
        ),
      );
    } else {
      final created = await controller.createHabit(
        title: title,
        description: desc,
        colorTag: _colorTag,
        frequency: _frequency,
        specificDays: _frequency == HabitFrequency.specificDays
            ? days
            : const [],
        targetDaysPerWeek: targetPerWeek,
      );
      ok = created != null;
    }

    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? 'Could not save habit'
              : (existing == null ? 'Habit created' : 'Habit saved'),
        ),
      ),
    );
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final habit = widget.habitToEdit;
    if (habit == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    final ok = await Get.find<HabitsController>().deleteHabit(habit.id);
    messenger?.showSnackBar(
      SnackBar(content: Text(ok ? 'Habit deleted' : 'Could not delete habit')),
    );
    if (!ok) return;
    // Close the sheet, and the detail page underneath it if one is open.
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.habitToEdit == null ? 'New habit' : 'Edit habit'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.habitToEdit != null)
            IconButton(
              tooltip: 'Delete habit',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: 'Save habit',
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            key: const ValueKey('habit-title'),
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Habit title',
              hintText: 'e.g., Read for 30 minutes',
              errorText: _error != null && _titleController.text.trim().isEmpty
                  ? _error
                  : null,
            ),
            autofocus: widget.habitToEdit == null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Why are you building this habit?',
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Repeats', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            children: [
              AppChip(
                label: 'Every day',
                isSelected: _frequency == HabitFrequency.daily,
                onSelected: (_) =>
                    setState(() => _frequency = HabitFrequency.daily),
              ),
              AppChip(
                label: 'Specific days',
                isSelected: _frequency == HabitFrequency.specificDays,
                onSelected: (_) =>
                    setState(() => _frequency = HabitFrequency.specificDays),
              ),
              AppChip(
                label: 'Times per week',
                isSelected: _frequency == HabitFrequency.weekly,
                onSelected: (_) =>
                    setState(() => _frequency = HabitFrequency.weekly),
              ),
            ],
          ),
          if (_frequency == HabitFrequency.specificDays) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: _days.contains(i + 1),
                      label: _dayNames[i],
                      child: ExcludeSemantics(
                        child: InkWell(
                          key: ValueKey('day-chip-${i + 1}'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() {
                            final d = i + 1;
                            if (!_days.remove(d)) _days.add(d);
                          }),
                          child: Container(
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _days.contains(i + 1)
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.16,
                                    )
                                  : theme.colorScheme.surfaceContainerHighest,
                              border: Border.all(
                                color: _days.contains(i + 1)
                                    ? theme.colorScheme.primary
                                    : semantic.hairline,
                              ),
                            ),
                            child: Text(_dayLetters[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null && _days.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
          if (_frequency == HabitFrequency.weekly) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                IconButton(
                  tooltip: 'Fewer times per week',
                  icon: const Icon(Icons.remove),
                  onPressed: _target > 1
                      ? () => setState(() => _target--)
                      : null,
                ),
                Text(
                  '$_target ${_target == 1 ? 'time' : 'times'} per week',
                  key: const ValueKey('weekly-target'),
                  style: theme.textTheme.bodyMedium,
                ),
                IconButton(
                  tooltip: 'More times per week',
                  icon: const Icon(Icons.add),
                  onPressed: _target < 7
                      ? () => setState(() => _target++)
                      : null,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Color tag', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.smPlus),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['default', ...CalendarColors.tags.keys].map((tag) {
                final color = tag == 'default'
                    ? semantic.habits
                    : CalendarColors.getTag(tag).color;
                final isSelected = _colorTag == tag;

                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: 'Color $tag',
                  child: GestureDetector(
                    onTap: () => setState(() => _colorTag = tag),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
