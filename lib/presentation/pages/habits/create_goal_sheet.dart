import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/goal.dart';
import '../../controllers/goals_controller.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/app_bottom_sheet_frame.dart';

class _MilestoneDraft {
  _MilestoneDraft({required this.id, String title = '', this.done = false})
    : controller = TextEditingController(text: title);

  final String id;
  final TextEditingController controller;
  bool done;
}

/// Create or edit a goal: title, target, optional date, linked habit and a
/// list of milestones.
class CreateGoalSheet extends StatefulWidget {
  const CreateGoalSheet({super.key, this.goalToEdit, this.initialHabitId});

  final Goal? goalToEdit;
  final String? initialHabitId;

  static Future<void> show(
    BuildContext context, {
    Goal? goalToEdit,
    String? initialHabitId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGoalSheet(
        goalToEdit: goalToEdit,
        initialHabitId: initialHabitId,
      ),
    );
  }

  @override
  State<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<CreateGoalSheet> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _drafts = <_MilestoneDraft>[];
  DateTime? _targetDate;
  String? _habitId;
  bool _isSaving = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final g = widget.goalToEdit;
    if (g != null) {
      _titleController.text = g.title;
      _targetController.text = g.targetDescription;
      _targetDate = g.targetDate;
      _habitId = g.linkedHabitId;
      for (final m in g.milestones) {
        _drafts.add(_MilestoneDraft(id: m.id, title: m.title, done: m.done));
      }
    } else {
      _habitId = widget.initialHabitId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    for (final d in _drafts) {
      d.controller.dispose();
    }
    super.dispose();
  }

  void _addMilestone() {
    setState(() => _drafts.add(_MilestoneDraft(id: const Uuid().v4())));
  }

  void _removeMilestone(_MilestoneDraft d) {
    setState(() => _drafts.remove(d));
    d.controller.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give the goal a title');
      return;
    }
    setState(() {
      _titleError = null;
      _isSaving = true;
    });
    final controller = GoalsController.ensureRegistered();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final existing = widget.goalToEdit;

    final milestones = [
      for (final d in _drafts)
        if (d.controller.text.trim().isNotEmpty)
          GoalMilestone(
            id: d.id,
            title: d.controller.text.trim(),
            done: d.done,
          ),
    ];

    bool ok;
    if (existing != null) {
      ok = await controller.updateGoal(
        existing.copyWith(
          title: title,
          targetDescription: _targetController.text.trim(),
          targetDate: _targetDate,
          clearTargetDate: _targetDate == null,
          linkedHabitId: _habitId,
          clearLinkedHabit: _habitId == null,
          milestones: milestones,
        ),
      );
    } else {
      final created = await controller.createGoal(
        title: title,
        targetDescription: _targetController.text,
        targetDate: _targetDate,
        linkedHabitId: _habitId,
        milestoneTitles: milestones.map((m) => m.title).toList(),
      );
      ok = created != null;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? 'Could not save goal'
              : (existing == null ? 'Goal created' : 'Goal saved'),
        ),
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final goal = widget.goalToEdit;
    if (goal == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await GoalsController.ensureRegistered().deleteGoal(goal.id);
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text(ok ? 'Goal deleted' : 'Could not delete goal')),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final editing = widget.goalToEdit != null;
    final habits = Get.isRegistered<HabitsController>()
        ? Get.find<HabitsController>().habits.toList()
        : const [];
    final linkedValid = habits.any((h) => h.id == _habitId);

    return AppBottomSheetFrame(
      title: editing ? 'Edit goal' : 'New goal',
      action: Row(
        children: [
          if (editing)
            TextButton(
              onPressed: _isSaving ? null : _delete,
              child: const Text('Delete'),
            ),
          const Spacer(),
          ElevatedButton(
            key: const ValueKey('save-goal'),
            onPressed: _isSaving ? null : _save,
            child: Text(editing ? 'Save changes' : 'Create goal'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('goal-title'),
            controller: _titleController,
            autofocus: !editing,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Goal',
              hintText: 'e.g. Run a 10k',
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('goal-target'),
            controller: _targetController,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Target',
              hintText: 'What does done look like?',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('goal-date'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    _targetDate == null
                        ? 'Target date'
                        : DateFormat('EEE, MMM d, y').format(_targetDate!),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_targetDate != null)
                IconButton(
                  tooltip: 'Clear target date',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _targetDate = null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            key: const ValueKey('goal-habit'),
            initialValue: linkedValid ? _habitId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Linked habit'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              for (final h in habits)
                DropdownMenuItem<String?>(
                  value: h.id,
                  child: Text(h.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _habitId = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'MILESTONES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: semantic.tertiaryText,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final d in _drafts)
            Row(
              key: ObjectKey(d),
              children: [
                Checkbox(
                  value: d.done,
                  onChanged: (v) => setState(() => d.done = v ?? false),
                ),
                Expanded(
                  child: TextField(
                    controller: d.controller,
                    decoration: const InputDecoration(
                      hintText: 'Milestone',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove milestone',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeMilestone(d),
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('add-milestone'),
              onPressed: _addMilestone,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add milestone'),
            ),
          ),
        ],
      ),
    );
  }
}
