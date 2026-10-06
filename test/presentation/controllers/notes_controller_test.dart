import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/entities/note.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/usecases/notes/convert_checklist_to_tasks.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/notes_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';

import '../../support/fake_note_repository.dart';
import 'task_controller_test.dart' show FakeAuthRepository, FakeTaskRepository;

void main() {
  const user = AppUser(uid: 'u1', email: 'a@b.c');
  late FakeNoteRepository repo;
  late FakeTaskRepository taskRepo;
  late AuthController auth;
  late NotesController controller;

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    auth = AuthController(authRepository: FakeAuthRepository(user));
    auth.onInit();
    await Future<void>.delayed(Duration.zero);
    repo = FakeNoteRepository();
    taskRepo = FakeTaskRepository();
    controller = NotesController(
      noteRepository: repo,
      authController: auth,
      convertChecklist: ConvertChecklistToTasks(taskRepo),
      searchDebounce: const Duration(milliseconds: 40),
    );
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(Get.reset);

  Future<Note> seed(
    String title, {
    String content = '',
    String category = 'General',
    List<String> tags = const [],
  }) async {
    final n = await controller.createNote(
      title,
      content,
      category: category,
      tags: tags,
    );
    return n!;
  }

  test(
    'createNote persists with category and tags and appears in list',
    () async {
      final n = await seed('Idea', category: 'Work', tags: ['a', 'b']);
      expect(repo.storage[n.id]!.category, 'Work');
      expect(repo.storage[n.id]!.tags, ['a', 'b']);
      expect(controller.notes.single.id, n.id);
    },
  );

  test(
    'createNote rolls back the optimistic insert when the write fails',
    () async {
      repo.failWrites = true;
      final n = await controller.createNote('x', 'y');
      expect(n, isNull);
      expect(controller.notes, isEmpty);
      expect(controller.errorMessage.value, contains('Failed to create note'));
    },
  );

  test('search is debounced and ranks title above content', () async {
    await seed('Groceries', content: 'plan dinner');
    await seed('Plan trip', content: 'flights');
    controller.setSearchInput('pl');
    controller.setSearchInput('plan');
    // Before debounce fires nothing is filtered yet.
    expect(controller.activeQuery.value, '');
    expect(controller.visibleNotes.length, 2);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.activeQuery.value, 'plan');
    expect(controller.visibleNotes.map((n) => n.title), [
      'Plan trip',
      'Groceries',
    ]);
    controller.clearSearch();
    expect(controller.visibleNotes.length, 2);
  });

  test('category and tag filters combine with search', () async {
    await seed('A', category: 'Work', tags: ['x']);
    await seed('B', category: 'Home', tags: ['x']);
    await seed('C', category: 'Work', tags: ['y']);
    controller.setCategory('Work');
    expect(controller.visibleNotes.map((n) => n.title).toSet(), {'A', 'C'});
    controller.setTag('x');
    expect(controller.visibleNotes.map((n) => n.title), ['A']);
    expect(controller.categories, ['Home', 'Work']);
    expect(controller.allTags, ['x', 'y']);
  });

  test('pin moves note to the top and persists', () async {
    final a = await seed('A');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await seed('B');
    expect(controller.notes.first.title, 'B');
    await controller.togglePin(a);
    expect(controller.notes.first.title, 'A');
    expect(repo.storage[a.id]!.isPinned, isTrue);
  });

  test(
    'archive then unarchive moves the note between lists and persists',
    () async {
      final a = await seed('A');
      expect(await controller.archiveNote(a), isTrue);
      expect(controller.notes, isEmpty);
      expect(controller.archivedNotes.single.id, a.id);
      expect(repo.storage[a.id]!.isArchived, isTrue);

      await controller.setShowArchived(true);
      expect(controller.visibleNotes.single.id, a.id);

      expect(
        await controller.unarchiveNote(controller.archivedNotes.single),
        isTrue,
      );
      expect(controller.archivedNotes, isEmpty);
      expect(controller.notes.single.id, a.id);
      expect(repo.storage[a.id]!.isArchived, isFalse);
    },
  );

  test('archive failure restores the note', () async {
    final a = await seed('A');
    repo.failWrites = true;
    expect(await controller.archiveNote(a), isFalse);
    expect(controller.notes.single.id, a.id);
    expect(controller.archivedNotes, isEmpty);
  });

  test(
    'toggleChecklistItem rewrites the line and persists the content',
    () async {
      final n = await seed('List', content: '- [ ] one\n- [ ] two');
      final next = await controller.toggleChecklistItem(n.id, 1);
      expect(next, '- [ ] one\n- [x] two');
      expect(repo.storage[n.id]!.content, '- [ ] one\n- [x] two');
      expect(controller.notes.single.content, '- [ ] one\n- [x] two');
      expect(await controller.toggleChecklistItem(n.id, 5), isNull);
    },
  );

  test('toggleChecklistItem reverts when the save fails', () async {
    final n = await seed('List', content: '- [ ] one');
    repo.failWrites = true;
    expect(await controller.toggleChecklistItem(n.id, 0), isNull);
    expect(controller.notes.single.content, '- [ ] one');
  });

  test(
    'convertChecklistToTasks creates tasks and refreshes TaskController',
    () async {
      final taskController = TaskController(
        taskRepository: taskRepo,
        authController: auth,
      );
      Get.put<TaskController>(taskController);
      taskController.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(taskController.tasks, isEmpty);

      final n = await seed(
        'Shop',
        content: '- [ ] milk\n- [ ] eggs\n- [x] old',
      );
      final first = await controller.convertChecklistToTasks(n);
      expect(first.created, 2);
      expect(taskController.tasks.map((t) => t.title).toSet(), {
        'milk',
        'eggs',
      });

      final second = await controller.convertChecklistToTasks(n);
      expect(second.created, 0);
      expect(taskController.tasks.length, 2);
    },
  );

  test('load failure sets an error and clears loading', () async {
    repo.failReads = true;
    await controller.loadNotes();
    expect(controller.errorMessage.value, contains('Failed to load notes'));
    expect(controller.isLoading.value, isFalse);
  });

  test('delete removes the note from list and storage', () async {
    final n = await seed('A');
    expect(await controller.deleteNote(n.id), isTrue);
    expect(controller.notes, isEmpty);
    expect(repo.storage, isEmpty);
  });
}
