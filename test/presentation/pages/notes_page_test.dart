import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/note.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/usecases/notes/convert_checklist_to_tasks.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/notes_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';
import 'package:omnilife/presentation/pages/notes/notes_page.dart';
import 'package:omnilife/presentation/widgets/app_chip.dart';

import '../../support/fake_note_repository.dart';
import '../controllers/task_controller_test.dart'
    show FakeAuthRepository, FakeTaskRepository;

void main() {
  const user = AppUser(uid: 'u1', email: 'a@b.c');
  late FakeNoteRepository repo;
  late FakeTaskRepository taskRepo;
  late AuthController auth;
  late NotesController controller;
  late TaskController taskController;

  Note note(
    String id,
    String title, {
    String content = '',
    List<String> tags = const [],
    String category = 'General',
  }) {
    final now = DateTime(2026, 5, 1, 12);
    return Note(
      id: id,
      userId: 'u1',
      title: title,
      content: content,
      tags: tags,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    auth = AuthController(authRepository: FakeAuthRepository(user));
    auth.onInit();
    await Future<void>.delayed(Duration.zero);
    repo = FakeNoteRepository();
    taskRepo = FakeTaskRepository();
    taskController = TaskController(
      taskRepository: taskRepo,
      authController: auth,
    );
    Get.put<TaskController>(taskController);
    taskController.onInit();
    controller = NotesController(
      noteRepository: repo,
      authController: auth,
      convertChecklist: ConvertChecklistToTasks(taskRepo),
      searchDebounce: const Duration(milliseconds: 30),
    );
    Get.put<NotesController>(controller);
  });

  tearDown(Get.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const NotesPage()),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows an empty state with an action when there are no notes', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('New Note'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when loading fails', (
    tester,
  ) async {
    repo.failReads = true;
    await pumpPage(tester);
    await controller.loadNotes();
    await tester.pump();
    expect(find.textContaining('Failed to load notes'), findsOneWidget);
    repo.failReads = false;
    repo.storage['a'] = note('a', 'Recovered');
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('search is debounced, ranked, and shows a no-match state', (
    tester,
  ) async {
    repo.storage['a'] = note('a', 'Groceries', content: 'plan dinner');
    repo.storage['b'] = note('b', 'Plan trip');
    repo.storage['c'] = note('c', 'Unrelated');
    await pumpPage(tester);
    await controller.loadNotes();
    await tester.pump();
    expect(find.text('Unrelated'), findsOneWidget);

    await tester.tap(find.byTooltip('Search notes'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('notes-search-field')),
      'plan',
    );
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Unrelated'), findsOneWidget, reason: 'still debouncing');
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Unrelated'), findsNothing);
    final plan = tester.getTopLeft(find.text('Plan trip'));
    final groceries = tester.getTopLeft(find.text('Groceries'));
    // Masonry fills row by row: first result is top-left.
    expect(
      plan.dy <= groceries.dy && plan.dx < groceries.dx,
      isTrue,
      reason: 'title match ranks first',
    );

    await tester.enterText(
      find.byKey(const ValueKey('notes-search-field')),
      'zzz',
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('No notes match'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('Unrelated'), findsOneWidget);
  });

  testWidgets('tag chip filters the grid', (tester) async {
    repo.storage['a'] = note('a', 'Alpha', tags: ['work']);
    repo.storage['b'] = note('b', 'Beta', tags: ['home']);
    await pumpPage(tester);
    await controller.loadNotes();
    await tester.pump();
    final workChip = find.descendant(
      of: find.byType(AppChip),
      matching: find.text('#work'),
    );
    await tester.ensureVisible(workChip);
    await tester.pumpAndSettle();
    await tester.tap(workChip);
    await tester.pump();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets(
    'open note, tick a checklist item, convert to tasks, confirm and dedupe',
    (tester) async {
      repo.storage['a'] = note(
        'a',
        'Shopping',
        content: '# Errands\n- [ ] milk\n- [ ] eggs\n- [x] bread',
      );
      await pumpPage(tester);
      await controller.loadNotes();
      await tester.pump();

      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      // Existing notes with content open rendered.
      expect(find.byKey(const ValueKey('checklist-line-1')), findsOneWidget);

      // Tapping the box persists immediately.
      await tester.tap(find.byKey(const ValueKey('checklist-line-1')));
      await tester.pumpAndSettle();
      expect(repo.storage['a']!.content, contains('- [x] milk'));

      // One unchecked item remains ("eggs").
      final convert = find.byKey(const ValueKey('convert-checklist'));
      expect(find.textContaining('Convert 1 unchecked item'), findsOneWidget);
      await tester.tap(convert);
      await tester.pumpAndSettle();
      expect(find.text('Created 1 task'), findsWidgets);
      expect(taskRepo.storage.map((t) => t.title), ['eggs']);
      expect(taskController.tasks.map((t) => t.title), ['eggs']);

      // Second click is a no-op with an explanatory message.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(convert);
      await tester.pumpAndSettle();
      expect(taskRepo.storage.length, 1);
      expect(find.textContaining('Already converted'), findsWidgets);
    },
  );

  testWidgets('editing category and tags in the sheet saves them', (
    tester,
  ) async {
    repo.storage['a'] = note('a', 'Plain', content: 'text');
    await pumpPage(tester);
    await controller.loadNotes();
    await tester.pump();
    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('note-category')), 'Work');
    await tester.enterText(find.byKey(const ValueKey('note-tags')), '#a, b a');
    await tester.tap(find.byTooltip('Save note'));
    await tester.pumpAndSettle();

    expect(repo.storage['a']!.category, 'Work');
    expect(repo.storage['a']!.tags, ['a', 'b']);
    expect(find.text('Note saved'), findsWidgets);
  });

  testWidgets('archive from the sheet moves the note to the archived view', (
    tester,
  ) async {
    repo.storage['a'] = note('a', 'Old thing', content: 'x');
    await pumpPage(tester);
    await controller.loadNotes();
    await tester.pump();
    await tester.tap(find.text('Old thing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Archive note'));
    await tester.pumpAndSettle();
    expect(find.text('Note archived'), findsWidgets);
    expect(repo.storage['a']!.isArchived, isTrue);
    expect(controller.notes, isEmpty);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Old thing'), findsOneWidget);
  });
}
