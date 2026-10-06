import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../domain/entities/note.dart';
import '../../../domain/usecases/notes/checklist_parser.dart';
import '../../controllers/notes_controller.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/calendar/calendar_colors.dart';
import '../../widgets/notes/markdown_note_view.dart';

/// Create / edit sheet for a note, with an Edit and a rendered Preview mode.
/// Checklist boxes in Preview toggle and persist immediately.
class CreateNoteSheet extends StatefulWidget {
  const CreateNoteSheet({super.key, this.noteToEdit});

  final Note? noteToEdit;

  static Future<void> show(BuildContext context, {Note? noteToEdit}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => CreateNoteSheet(noteToEdit: noteToEdit),
    );
  }

  @override
  State<CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<CreateNoteSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  String _colorTag = 'default';
  bool _isSaving = false;
  bool _preview = false;

  /// The persisted note, once it exists (edit mode, or after first save).
  Note? _note;

  NotesController get _controller => Get.find<NotesController>();

  @override
  void initState() {
    super.initState();
    final n = widget.noteToEdit;
    _note = n;
    if (n != null) {
      _titleController.text = n.title;
      _contentController.text = n.content;
      _categoryController.text = n.category == 'General' ? '' : n.category;
      _tagsController.text = n.tags.join(', ');
      _colorTag = n.colorTag;
      _preview = n.content.trim().isNotEmpty;
    }
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in _tagsController.text.split(RegExp(r'[,\s]+'))) {
      final t = raw.replaceFirst(RegExp(r'^#+'), '').trim();
      if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
      out.add(t);
    }
    return out;
  }

  String get _category {
    final c = _categoryController.text.trim();
    return c.isEmpty ? 'General' : c;
  }

  bool get _isBlank =>
      _titleController.text.trim().isEmpty &&
      _contentController.text.trim().isEmpty;

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _close() => Navigator.of(context).pop();

  /// Writes the current form to storage. Returns the stored note or null.
  Future<Note?> _persist() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trimRight();
    final existing = _note;
    if (existing != null) {
      final updated = existing.copyWith(
        title: title,
        content: content,
        category: _category,
        colorTag: _colorTag,
        tags: _parseTags(),
      );
      final ok = await _controller.updateNote(updated);
      if (!ok) return null;
      _note = updated;
      return updated;
    }
    final created = await _controller.createNote(
      title,
      content,
      category: _category,
      colorTag: _colorTag,
      tags: _parseTags(),
    );
    _note = created;
    return created;
  }

  Future<void> _save() async {
    if (_isBlank && _note == null) {
      _close();
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final isNew = _note == null;
    setState(() => _isSaving = true);
    final saved = await _persist();
    if (!mounted) return;
    if (saved == null) {
      setState(() => _isSaving = false);
      _toast('Could not save note', error: true);
      return;
    }
    messenger?.showSnackBar(
      SnackBar(content: Text(isNew ? 'Note created' : 'Note saved')),
    );
    _close();
  }

  Future<void> _delete() async {
    final note = _note;
    if (note == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _controller.deleteNote(note.id);
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text(ok ? 'Note deleted' : 'Could not delete note')),
    );
    if (ok) _close();
  }

  Future<void> _togglePin() async {
    final note = _note;
    if (note == null) return;
    final ok = await _controller.togglePin(note);
    if (!mounted || !ok) return;
    final fresh =
        _controller.notes.firstWhereOrNull((n) => n.id == note.id) ??
        _controller.archivedNotes.firstWhereOrNull((n) => n.id == note.id);
    setState(() => _note = fresh ?? note.copyWith(isPinned: !note.isPinned));
    _toast(_note!.isPinned ? 'Note pinned' : 'Note unpinned');
  }

  Future<void> _toggleArchive() async {
    final saved = await _persist();
    if (saved == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final wasArchived = saved.isArchived;
    final ok = wasArchived
        ? await _controller.unarchiveNote(saved)
        : await _controller.archiveNote(saved);
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          !ok
              ? 'Could not update note'
              : (wasArchived ? 'Note restored' : 'Note archived'),
        ),
      ),
    );
    if (ok) _close();
  }

  Future<void> _onToggleChecklist(int lineIndex) async {
    final next = ChecklistParser.toggle(_contentController.text, lineIndex);
    if (next == _contentController.text) return;
    _contentController.text = next;
    // Persist right away for notes that already exist.
    if (_note != null) {
      final saved = await _persist();
      if (saved == null && mounted) {
        _toast('Could not save checklist change', error: true);
      }
    }
  }

  Future<void> _convertChecklist() async {
    setState(() => _isSaving = true);
    try {
      final saved = await _persist();
      if (saved == null) {
        if (mounted) _toast('Save the note first', error: true);
        return;
      }
      final result = await _controller.convertChecklistToTasks(saved);
      if (mounted) _toast(result.message);
    } catch (e) {
      if (mounted) _toast('Could not create tasks: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final unchecked = ChecklistParser.unchecked(_contentController.text).length;
    final note = _note;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(note == null ? 'New note' : 'Note'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        actions: [
          if (note != null) ...[
            IconButton(
              tooltip: note.isPinned ? 'Unpin note' : 'Pin note',
              icon: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              onPressed: _togglePin,
            ),
            IconButton(
              tooltip: note.isArchived ? 'Restore note' : 'Archive note',
              icon: Icon(
                note.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              onPressed: _toggleArchive,
            ),
            IconButton(
              tooltip: 'Delete note',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
          IconButton(
            tooltip: 'Save note',
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.sm,
          AppSpacing.screenPadding,
          AppSpacing.xl,
        ),
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['default', ...CalendarColors.tags.keys].map((tag) {
                final color = tag == 'default'
                    ? semantic.hairline
                    : CalendarColors.getTag(tag).color;
                final selected = _colorTag == tag;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Color $tag',
                  child: GestureDetector(
                    onTap: () => setState(() => _colorTag = tag),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selected
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
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('note-title'),
            controller: _titleController,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            maxLines: null,
            textInputAction: TextInputAction.next,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('note-category'),
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'General',
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: const ValueKey('note-tags'),
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'work, ideas',
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppChip(
                  label: 'Edit',
                  isSelected: !_preview,
                  onSelected: (_) => setState(() => _preview = false),
                ),
                AppChip(
                  label: 'Preview',
                  isSelected: _preview,
                  onSelected: (_) => setState(() => _preview = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_preview)
            MarkdownNoteView(
              content: _contentController.text,
              onToggleChecklist: _onToggleChecklist,
            )
          else
            TextField(
              key: const ValueKey('note-content'),
              controller: _contentController,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Start writing. Markdown and - [ ] checklists work.',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              minLines: 6,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          if (unchecked > 0) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('convert-checklist'),
              onPressed: _isSaving ? null : _convertChecklist,
              icon: const Icon(Icons.playlist_add_check, size: 18),
              label: Text(
                'Convert $unchecked unchecked '
                '${unchecked == 1 ? 'item' : 'items'} to tasks',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
