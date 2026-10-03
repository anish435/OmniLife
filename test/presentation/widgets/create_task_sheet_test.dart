import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';
import 'package:omnilife/presentation/widgets/create_task_sheet.dart';

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo(this._user);
  final AppUser? _user;
  final _ctrl = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> authStateChanges() => _ctrl.stream;
  @override
  AppUser? get currentUser => _user;
  @override
  Future<AppUser> login({required String email, required String password}) async => throw UnimplementedError();
  @override
  Future<AppUser> register({required String email, required String password}) async => throw UnimplementedError();
  @override
  Future<AppUser> signInWithGoogle() async => throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _FakeTaskRepo implements TaskRepository {
  final List<Task> tasks = [];

  @override
  Future<List<Task>> getTasks(String userId) async => tasks;
  @override
  Future<Task?> getTask(String id) async => null;
  @override
  Future<Task> createTask(Task task) async {
    tasks.add(task);
    return task;
  }
  @override
  Future<Task> updateTask(Task task) async => task;
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<Task> completeTask(String id) async => throw UnimplementedError();
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('validates empty title when submitting', (tester) async {
    final authRepo = _FakeAuthRepo(const AppUser(uid: 'u1', email: 'test@example.com'));
    final authController = AuthController(authRepository: authRepo);
    final taskRepo = _FakeTaskRepo();
    final taskController = TaskController(taskRepository: taskRepo, authController: authController);

    Get.put(taskController);
    Get.put(authController);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => CreateTaskSheet.show(ctx),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('New Task'), findsOneWidget);

    // Tap 'Create Task' with empty title
    await tester.tap(find.text('Create Task'));
    await tester.pumpAndSettle();

    expect(find.text('Title cannot be empty'), findsOneWidget);
    expect(taskRepo.tasks.isEmpty, isTrue);
  });

  testWidgets('creates task successfully with title and dismisses modal', (tester) async {
    final authRepo = _FakeAuthRepo(const AppUser(uid: 'u1', email: 'test@example.com'));
    final authController = AuthController(authRepository: authRepo);
    final taskRepo = _FakeTaskRepo();
    final taskController = TaskController(taskRepository: taskRepo, authController: authController);

    Get.put(taskController);
    Get.put(authController);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => CreateTaskSheet.show(ctx),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('New Task'), findsOneWidget);

    // Enter title 'dd'
    await tester.enterText(find.byType(TextFormField).first, 'dd');
    await tester.pump();

    // Tap Create Task
    await tester.tap(find.text('Create Task'));
    await tester.pumpAndSettle();

    // Verify task created in repo and modal is closed
    expect(taskRepo.tasks.length, 1);
    expect(taskRepo.tasks.first.title, 'dd');
    expect(find.text('New Task'), findsNothing);
  });
}
