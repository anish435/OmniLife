import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/entities/note.dart';
import '../../controllers/notes_controller.dart';
import '../../widgets/calendar/calendar_colors.dart';

class CreateNoteSheet extends StatefulWidget {
  const CreateNoteSheet({super.key, this.noteToEdit});

  final Note? noteToEdit;

  static void show(BuildContext context, {Note? noteToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CreateNoteSheet(noteToEdit: noteToEdit),
    );
  }

  @override
  State<CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<CreateNoteSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _colorTag = 'default';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.noteToEdit != null) {
      _titleController.text = widget.noteToEdit!.title;
      _contentController.text = widget.noteToEdit!.content;
      _colorTag = widget.noteToEdit!.colorTag;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Get.back();
      return;
    }

    setState(() => _isSaving = true);
    final controller = Get.find<NotesController>();

    if (widget.noteToEdit != null) {
      await controller.updateNote(
        widget.noteToEdit!.copyWith(
          title: title,
          content: content,
          colorTag: _colorTag,
        ),
      );
    } else {
      await controller.createNote(
        title,
        content,
        colorTag: _colorTag,
      );
    }

    if (mounted) Get.back();
  }
  
  Future<void> _delete() async {
    if (widget.noteToEdit == null) return;
    final controller = Get.find<NotesController>();
    await controller.deleteNote(widget.noteToEdit!.id);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (widget.noteToEdit != null)
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
      body: Column(
        children: [
          // Color Tag Selector
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['default', ...CalendarColors.tags.keys].map((tag) {
                final color = tag == 'default' 
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                    : CalendarColors.getTag(tag).color;
                final isSelected = _colorTag == tag;
                
                return GestureDetector(
                  onTap: () => setState(() => _colorTag = tag),
                  child: Container(
                    width: 24,
                    height: 24,
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
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                TextField(
                  controller: _titleController,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: _contentController,
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
