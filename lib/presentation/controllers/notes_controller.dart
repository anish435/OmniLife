import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/notes/checklist_parser.dart';
import '../../domain/usecases/notes/convert_checklist_to_tasks.dart';
import '../../domain/usecases/notes/note_search_ranker.dart';
import 'auth_controller.dart';
import 'task_controller.dart';

class NotesController extends GetxController {
  NotesController({
    NoteRepository? noteRepository,
    AuthController? authController,
    ConvertChecklistToTasks? convertChecklist,
    this.searchDebounce = const Duration(milliseconds: 250),
  }) : _injectedRepository = noteRepository,
       _injectedAuth = authController,
       _injectedConvert = convertChecklist;

  final NoteRepository? _injectedRepository;
  final AuthController? _injectedAuth;
  final ConvertChecklistToTasks? _injectedConvert;
  final Duration searchDebounce;

  NoteRepository get _noteRepository =>
      _injectedRepository ?? Get.find<NoteRepository>();
  AuthController get _authController =>
      _injectedAuth ?? Get.find<AuthController>();
  ConvertChecklistToTasks get _convert =>
      _injectedConvert ?? ConvertChecklistToTasks(Get.find<TaskRepository>());

  final notes = <Note>[].obs;
  final archivedNotes = <Note>[].obs;

  final isLoading = false.obs;
  final errorMessage = Rx<String?>(null);

  /// Raw text in the search box (updates on every keystroke).
  final searchInput = ''.obs;

  /// Debounced query that actually drives [visibleNotes].
  final activeQuery = ''.obs;
  final selectedCategory = Rxn<String>();
  final selectedTag = Rxn<String>();
  final showArchived = false.obs;

  String get _currentUserId => _authController.currentUser.value?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    // Load notes when the user changes
    ever(_authController.currentUser, (_) => loadNotes());
    if (_authController.currentUser.value != null) {
      loadNotes();
    }
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }

  // ---------------------------------------------------------------- loading

  Future<void> loadNotes() async {
    if (_currentUserId.isEmpty) {
      notes.clear();
      archivedNotes.clear();
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loaded = await _noteRepository.getNotes(_currentUserId);
      notes.assignAll(loaded);
      if (showArchived.value) await loadArchivedNotes();
    } catch (e) {
      errorMessage.value = 'Failed to load notes: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadArchivedNotes() async {
    if (_currentUserId.isEmpty) return;

    try {
      final loaded = await _noteRepository.getArchivedNotes(_currentUserId);
      archivedNotes.assignAll(loaded);
    } catch (e) {
      errorMessage.value = 'Failed to load archived notes: $e';
    }
  }

  // ----------------------------------------------------- search and filters

  Timer? _debounceTimer;

  void setSearchInput(String value) {
    searchInput.value = value;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(searchDebounce, () {
      activeQuery.value = value.trim();
    });
  }

  /// Skips the debounce (used when clearing the box or in tests).
  void clearSearch() {
    _debounceTimer?.cancel();
    searchInput.value = '';
    activeQuery.value = '';
  }

  Future<void> setShowArchived(bool value) async {
    showArchived.value = value;
    if (value) await loadArchivedNotes();
  }

  void setCategory(String? category) => selectedCategory.value = category;
  void setTag(String? tag) => selectedTag.value = tag;

  List<Note> get _pool => showArchived.value ? archivedNotes : notes;

  List<String> get categories {
    final set = <String>{
      for (final n in [...notes, ...archivedNotes])
        if (n.category.trim().isNotEmpty) n.category.trim(),
    };
    return set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> get allTags {
    final set = <String>{
      for (final n in [...notes, ...archivedNotes]) ...n.tags,
    };
    return set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  bool get hasActiveFilters =>
      activeQuery.value.isNotEmpty ||
      selectedCategory.value != null ||
      selectedTag.value != null;

  /// Notes after category / tag filters and ranked search. Reads only Rx
  /// fields, so an `Obx` calling this rebuilds on any relevant change.
  List<Note> get visibleNotes {
    Iterable<Note> pool = _pool;
    final category = selectedCategory.value;
    final tag = selectedTag.value;
    if (category != null) {
      pool = pool.where((n) => n.category == category);
    }
    if (tag != null) {
      pool = pool.where((n) => n.tags.contains(tag));
    }
    final query = activeQuery.value;
    if (query.isEmpty) return pool.toList();
    return NoteSearchRanker.rank(pool, query).map((r) => r.note).toList();
  }

  /// Programmatic search that bypasses the UI state (kept for callers that
  /// want ranked results across active and archived notes).
  Future<List<Note>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return NoteSearchRanker.rank([
      ...notes,
      ...archivedNotes,
    ], query).map((r) => r.note).toList();
  }

  // ------------------------------------------------------------------- CRUD

  Future<Note?> createNote(
    String title,
    String content, {
    String category = 'General',
    String colorTag = 'default',
    List<String> tags = const [],
  }) async {
    if (_currentUserId.isEmpty) return null;

    final now = DateTime.now();
    final newNote = Note(
      id: const Uuid().v4(),
      userId: _currentUserId,
      title: title,
      content: content,
      category: category.trim().isEmpty ? 'General' : category.trim(),
      colorTag: colorTag,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic UI update
    notes.insert(0, newNote);
    _sortNotes();

    try {
      final created = await _noteRepository.createNote(newNote);
      final idx = notes.indexWhere((e) => e.id == newNote.id);
      if (idx != -1) {
        notes[idx] = created;
      }
      return created;
    } catch (e) {
      notes.removeWhere((e) => e.id == newNote.id);
      errorMessage.value = 'Failed to create note: $e';
      return null;
    }
  }

  Future<bool> updateNote(Note note) async {
    if (_currentUserId.isEmpty) return false;

    final updated = note.copyWith(updatedAt: DateTime.now());

    final idx = notes.indexWhere((e) => e.id == note.id);
    final archIdx = archivedNotes.indexWhere((e) => e.id == note.id);
    final previous = idx != -1
        ? notes[idx]
        : (archIdx != -1 ? archivedNotes[archIdx] : null);
    if (idx != -1) {
      notes[idx] = updated;
    } else if (archIdx != -1) {
      archivedNotes[archIdx] = updated;
    }

    try {
      await _noteRepository.updateNote(updated);
      _sortNotes();
      return true;
    } catch (e) {
      if (previous != null) {
        if (idx != -1) {
          notes[idx] = previous;
        } else if (archIdx != -1) {
          archivedNotes[archIdx] = previous;
        }
      }
      errorMessage.value = 'Failed to update note: $e';
      return false;
    }
  }

  Future<bool> togglePin(Note note) async {
    final current = _find(note.id) ?? note;
    return updateNote(current.copyWith(isPinned: !current.isPinned));
  }

  Future<bool> archiveNote(Note note) async {
    final current = _find(note.id) ?? note;
    final updated = current.copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
    notes.removeWhere((e) => e.id == note.id);
    archivedNotes.removeWhere((e) => e.id == note.id);
    archivedNotes.insert(0, updated);

    try {
      await _noteRepository.updateNote(updated);
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to archive note: $e';
      archivedNotes.removeWhere((e) => e.id == note.id);
      notes.add(current);
      _sortNotes();
      return false;
    }
  }

  Future<bool> unarchiveNote(Note note) async {
    final current = _find(note.id) ?? note;
    final updated = current.copyWith(
      isArchived: false,
      updatedAt: DateTime.now(),
    );
    archivedNotes.removeWhere((e) => e.id == note.id);
    notes.removeWhere((e) => e.id == note.id);
    notes.add(updated);
    _sortNotes();

    try {
      await _noteRepository.updateNote(updated);
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to restore note: $e';
      notes.removeWhere((e) => e.id == note.id);
      archivedNotes.insert(0, current);
      return false;
    }
  }

  Future<bool> deleteNote(String id) async {
    final existingIdx = notes.indexWhere((e) => e.id == id);
    Note? existing;
    if (existingIdx != -1) {
      existing = notes[existingIdx];
      notes.removeAt(existingIdx);
    } else {
      final archIdx = archivedNotes.indexWhere((e) => e.id == id);
      if (archIdx != -1) {
        existing = archivedNotes[archIdx];
        archivedNotes.removeAt(archIdx);
      }
    }

    try {
      await _noteRepository.deleteNote(id);
      return true;
    } catch (e) {
      if (existing != null) {
        if (existing.isArchived) {
          archivedNotes.add(existing);
        } else {
          notes.add(existing);
        }
        _sortNotes();
      }
      errorMessage.value = 'Failed to delete note: $e';
      return false;
    }
  }

  // -------------------------------------------------------------- checklists

  /// Flips the checkbox on [lineIndex] of note [noteId] and persists it.
  /// Returns the new content, or null if nothing changed / the save failed.
  Future<String?> toggleChecklistItem(String noteId, int lineIndex) async {
    final note = _find(noteId);
    if (note == null) return null;
    final next = ChecklistParser.toggle(note.content, lineIndex);
    if (next == note.content) return null;
    final ok = await updateNote(note.copyWith(content: next));
    return ok ? next : null;
  }

  /// Creates tasks for the unchecked items of [note] (deduplicated) and
  /// refreshes the Tasks list so the new tasks and dashboard counts update.
  Future<ConvertChecklistResult> convertChecklistToTasks(Note note) async {
    final result = await _convert(note);
    if (result.created > 0 && Get.isRegistered<TaskController>()) {
      await Get.find<TaskController>().loadTasks();
    }
    return result;
  }

  // ----------------------------------------------------------------- helpers

  Note? _find(String id) =>
      notes.firstWhereOrNull((e) => e.id == id) ??
      archivedNotes.firstWhereOrNull((e) => e.id == id);

  void _sortNotes() {
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
}
