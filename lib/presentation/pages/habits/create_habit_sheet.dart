import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/entities/habit.dart';
import '../../controllers/habits_controller.dart';
import '../../widgets/calendar/calendar_colors.dart';

class CreateHabitSheet extends StatefulWidget {
  const CreateHabitSheet({super.key, this.habitToEdit});

  final Habit? habitToEdit;

  static void show(BuildContext context, {Habit? habitToEdit}) {
    showModalBottomSheet(
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _colorTag = 'default';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.habitToEdit != null) {
      _titleController.text = widget.habitToEdit!.title;
      _descriptionController.text = widget.habitToEdit!.description;
      _colorTag = widget.habitToEdit!.colorTag;
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
    final desc = _descriptionController.text.trim();

    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    final controller = Get.find<HabitsController>();

    if (widget.habitToEdit != null) {
      await controller.updateHabit(
        widget.habitToEdit!.copyWith(
          title: title,
          description: desc,
          colorTag: _colorTag,
        ),
      );
    } else {
      await controller.createHabit(
        title: title,
        description: desc,
        colorTag: _colorTag,
      );
    }

    if (mounted) Get.back();
  }

  Future<void> _delete() async {
    if (widget.habitToEdit == null) return;
    final controller = Get.find<HabitsController>();
    await controller.deleteHabit(widget.habitToEdit!.id);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.habitToEdit == null ? 'New Habit' : 'Edit Habit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (widget.habitToEdit != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Habit Title',
              hintText: 'e.g., Read for 30 minutes',
            ),
            autofocus: widget.habitToEdit == null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Why are you building this habit?',
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 24),
          Text('Color Tag', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['default', ...CalendarColors.tags.keys].map((tag) {
                final color = tag == 'default' 
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                    : CalendarColors.getTag(tag).color;
                final isSelected = _colorTag == tag;
                
                return GestureDetector(
                  onTap: () => setState(() => _colorTag = tag),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(
                        color: theme.colorScheme.onSurface,
                        width: 2,
                      ) : null,
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
