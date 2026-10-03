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
import 'package:omnilife/presentation/widgets/calendar/create_event_sheet.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._current);

  final _controller = StreamController<AppUser?>.broadcast();
  final AppUser? _current;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> register({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<AppUser> login({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<AppUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _FakeCalendarRepository implements CalendarRepository {
  final List<CalendarEvent> storage = [];

  @override
  Future<List<CalendarEvent>> getEventsForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async =>
      storage;

  @override
  Future<CalendarEvent?> getEvent(String id) async => null;

  @override
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    storage.add(event);
    return event;
  }

  @override
  Future<CalendarEvent> updateEvent(CalendarEvent event) async => event;

  @override
  Future<void> deleteEvent(String id) async {}
}

class _FakeTaskRepository implements TaskRepository {
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

void main() {
  const testUser = AppUser(
    uid: 'u_sheet_1',
    email: 'sheet@test.com',
    displayName: 'Sheet Tester',
  );

  late _FakeAuthRepository authRepo;
  late _FakeCalendarRepository calRepo;
  late _FakeTaskRepository taskRepo;

  setUp(() {
    Get.testMode = true;
    authRepo = _FakeAuthRepository(testUser);
    calRepo = _FakeCalendarRepository();
    taskRepo = _FakeTaskRepository();

    Get.put(AuthController(authRepository: authRepo));
    Get.put(TaskController(taskRepository: taskRepo));
    Get.put(CalendarController(
      calendarRepository: calRepo,
      taskController: Get.find<TaskController>(),
      authController: Get.find<AuthController>(),
    ));
  });

  tearDown(() {
    Get.reset();
  });

  Widget createSubject() {
    return GetMaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CreateEventSheet.show(context),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  testWidgets('validates empty title when submitting', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Tap "Create Event" with empty title
    await tester.tap(find.text('Create Event'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter an event title'), findsOneWidget);
  });

  testWidgets('creates event successfully with valid inputs', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Enter title
    await tester.enterText(find.byType(TextFormField).first, 'Sprint Retrospective');
    await tester.pump();

    // Tap "Create Event"
    await tester.tap(find.text('Create Event'));
    await tester.pumpAndSettle();

    final calController = Get.find<CalendarController>();
    expect(calController.events, hasLength(1));
    expect(calController.events.first.title, 'Sprint Retrospective');
  });
}
