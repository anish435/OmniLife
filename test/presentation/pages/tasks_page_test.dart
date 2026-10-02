import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';
import 'package:omnilife/presentation/pages/tasks/tasks_page.dart';

import '../controllers/task_controller_test.dart' show FakeAuthRepository, FakeTaskRepository;

void main() {
  const testUser = AppUser(uid: 'uid-1', email: 'test@example.com');
  late FakeAuthRepository authRepo;
  late AuthController authController;
  late FakeTaskRepository taskRepo;
  late TaskController taskController;

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    authRepo = FakeAuthRepository(testUser);
    authController = AuthController(authRepository: authRepo);
    authController.onInit();
    await Future<void>.delayed(Duration.zero);

    taskRepo = FakeTaskRepository();
    taskController = TaskController(
      taskRepository: taskRepo,
      authController: authController,
    );
    taskController.onInit();
    await Future<void>.delayed(Duration.zero);

    Get.put<AuthRepository>(authRepo);
    Get.put<AuthController>(authController);
    Get.put<TaskRepository>(taskRepo);
    Get.put<TaskController>(taskController);
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpTasksPage(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const TasksPage(),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders header, filter tabs, and empty state when empty', (tester) async {
    await pumpTasksPage(tester);

    expect(find.text('Tasks & Projects'), findsOneWidget);
    expect(find.textContaining('All'), findsOneWidget);
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);

    expect(find.text('No tasks in this view'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('renders task card when tasks are present', (tester) async {
    await taskController.createTask(
      title: 'Design high-converting landing page',
      priority: TaskPriority.high,
    );

    await pumpTasksPage(tester);

    expect(find.text('Design high-converting landing page'), findsOneWidget);
    // 1 in priority pill filter bar, 1 in the task card badge
    expect(find.text('HIGH'), findsNWidgets(2));
  });

  testWidgets('tapping search button reveals search field and filters', (tester) async {
    await taskController.createTask(title: 'Apple recipe');
    await taskController.createTask(title: 'Banana smoothie');

    await pumpTasksPage(tester);

    expect(find.text('Apple recipe'), findsOneWidget);
    expect(find.text('Banana smoothie'), findsOneWidget);

    // Tap search icon in AppBar
    final searchIcon = find.byIcon(Icons.search);
    expect(searchIcon, findsOneWidget);
    await tester.tap(searchIcon);
    await tester.pump();

    // Type 'apple' into the search input
    final searchField = find.widgetWithText(TextField, 'Search tasks...');
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'apple');
    await tester.pump();

    expect(find.text('Apple recipe'), findsOneWidget);
    expect(find.text('Banana smoothie'), findsNothing);
  });

  testWidgets('tapping FAB opens the create task bottom sheet', (tester) async {
    await pumpTasksPage(tester);

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();

    // FAB label + modal header
    expect(find.text('New Task'), findsNWidgets(2));
    // Empty view action button + bottom sheet submit button
    expect(find.text('Create Task'), findsNWidgets(2));
  });
}
