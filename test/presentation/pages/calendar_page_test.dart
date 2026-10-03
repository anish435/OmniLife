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
import 'package:omnilife/presentation/controllers/app_controller.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/calendar_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';
import 'package:omnilife/presentation/pages/calendar/calendar_page.dart';

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
  final List<CalendarEvent> events = [];

  @override
  Future<List<CalendarEvent>> getEventsForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async =>
      events;

  @override
  Future<CalendarEvent?> getEvent(String id) async => null;

  @override
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    events.add(event);
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
    uid: 'u_cal_1',
    email: 'cal@test.com',
    displayName: 'Calendar Tester',
  );

  late _FakeAuthRepository authRepo;
  late _FakeCalendarRepository calRepo;
  late _FakeTaskRepository taskRepo;

  setUp(() {
    Get.testMode = true;
    authRepo = _FakeAuthRepository(testUser);
    calRepo = _FakeCalendarRepository();
    taskRepo = _FakeTaskRepository();

    Get.put(AppController());
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

  Widget createSubject({ThemeData? theme, TextScaler? textScaler}) {
    return GetMaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          textScaler: textScaler ?? TextScaler.noScaling,
        ),
        child: const CalendarPage(),
      ),
    );
  }

  testWidgets('renders month view with weekday headers and view switcher', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pump();

    // Check weekday labels
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('FRI'), findsOneWidget);

    // Check ViewModeSwitcher buttons
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);

    // Empty agenda prompt
    expect(find.text('Nothing scheduled.'), findsOneWidget);
  });

  testWidgets('switching to Week view updates layout without error', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pump();

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final controller = Get.find<CalendarController>();
    expect(controller.viewMode.value, CalendarViewMode.week);
  });

  testWidgets('switching to Day view displays 24-hour timeline', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pump();

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    final controller = Get.find<CalendarController>();
    expect(controller.viewMode.value, CalendarViewMode.day);

    // Check timeline labels
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('renders cleanly in dark theme without overflow', (tester) async {
    await tester.pumpWidget(createSubject(theme: AppTheme.dark));
    await tester.pump();

    expect(find.byType(CalendarPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts safely at 360px width with 1.3 textScaler', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSubject(
      textScaler: const TextScaler.linear(1.3),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CalendarPage), findsOneWidget);
  });
}
