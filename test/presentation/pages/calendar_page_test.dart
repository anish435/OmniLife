import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/calendar_event.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/calendar_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/calendar_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';
import 'package:omnilife/presentation/pages/calendar/calendar_page.dart';

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
  @override
  Future<List<Task>> getTasks(String userId) async => [];
  @override
  Future<Task?> getTask(String id) async => null;
  @override
  Future<Task> createTask(Task task) async => task;
  @override
  Future<Task> updateTask(Task task) async => task;
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<Task> completeTask(String id) async => throw UnimplementedError();
}

class _FakeCalendarRepo implements CalendarRepository {
  @override
  Future<List<CalendarEvent>> getEventsForRange(String userId, DateTime start, DateTime end) async => [];
  @override
  Future<CalendarEvent?> getEvent(String id) async => null;
  @override
  Future<CalendarEvent> createEvent(CalendarEvent event) async => event;
  @override
  Future<CalendarEvent> updateEvent(CalendarEvent event) async => event;
  @override
  Future<void> deleteEvent(String id) async {}
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('CalendarPage renders without throwing even when controllers are registered', (tester) async {
    final authRepo = _FakeAuthRepo(const AppUser(uid: 'u1', email: 'test@example.com'));
    final authController = AuthController(authRepository: authRepo);
    final taskRepo = _FakeTaskRepo();
    final taskController = TaskController(taskRepository: taskRepo, authController: authController);
    final calRepo = _FakeCalendarRepo();
    final calController = CalendarController(
      calendarRepository: calRepo,
      taskController: taskController,
      authController: authController,
    );

    Get.put<AuthRepository>(authRepo);
    Get.put(authController, permanent: true);
    Get.put<TaskRepository>(taskRepo);
    Get.put(taskController, permanent: true);
    Get.put<CalendarRepository>(calRepo);
    Get.put(calController, permanent: true);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const CalendarPage(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify calendar header and views
    expect(find.byType(CalendarPage), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('Nothing scheduled.'), findsOneWidget);
  });
}
