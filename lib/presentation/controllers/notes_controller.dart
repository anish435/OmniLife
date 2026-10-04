import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import 'auth_controller.dart';

class NotesController extends GetxController {
  final _noteRepository = Get.find<NoteRepository>();
  final _authController = Get.find<AuthController>();

  final notes = <Note>[].obs;
  final archivedNotes = <Note>[].obs;
  
  final isLoading = false.obs;
  final errorMessage = Rx<String?>(null);

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

  Future<void> loadNotes() async {
    if (_currentUserId.isEmpty) return;
    
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loaded = await _noteRepository.getNotes(_currentUserId);
      notes.assignAll(loaded);
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

  Future<Note?> createNote(String title, String content, {String category = 'General', String colorTag = 'default', List<String> tags = const []}) async {
    if (_currentUserId.isEmpty) return null;

    final now = DateTime.now();
    final newNote = Note(
      id: Uuid().v4(),
      userId: _currentUserId,
      title: title,
      content: content,
      category: category,
      colorTag: colorTag,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic UI update
    notes.insert(0, newNote);

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
    if (idx != -1) {
      notes[idx] = updated;
    } else {
      final archIdx = archivedNotes.indexWhere((e) => e.id == note.id);
      if (archIdx != -1) archivedNotes[archIdx] = updated;
    }

    try {
      await _noteRepository.updateNote(updated);
      _sortNotes();
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to update note: $e';
      return false;
    }
  }
  
  Future<bool> togglePin(Note note) async {
    final updated = note.copyWith(isPinned: !note.isPinned);
    return updateNote(updated);
  }
  
  Future<bool> archiveNote(Note note) async {
    final updated = note.copyWith(isArchived: true);
    notes.removeWhere((e) => e.id == note.id);
    archivedNotes.add(updated);
    
    try {
      await _noteRepository.updateNote(updated);
      return true;
    } catch (e) {
      loadNotes(); // Revert on failure
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

  void _sortNotes() {
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }
  
  Future<List<Note>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return _noteRepository.searchNotes(_currentUserId, query);
  }
}
