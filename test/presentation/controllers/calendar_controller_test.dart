import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/entities/calendar_event.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/calendar_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/calendar_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._current]);

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  void emit(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    late StreamController<AppUser?> sc;
    sc = StreamController<AppUser?>.broadcast(
      onListen: () {
        sc.add(_current);
        final sub = _controller.stream.listen(sc.add);
        sc.onCancel = () => sub.cancel();
      },
    );
    return sc.stream;
  }

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
  Future<void> logout() async => emit(null);

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class FakeCalendarRepository implements CalendarRepository {
  final List<CalendarEvent> storage = [];

  @override
  Future<List<CalendarEvent>> getEventsForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return storage.where((e) {
      if (e.userId != userId) return false;
      return e.startAt.isBefore(end) && e.endAt.isAfter(start);
    }).toList();
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    final matches = storage.where((e) => e.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    storage.add(event);
    return event;
  }

  @override
  Future<CalendarEvent> updateEvent(CalendarEvent event) async {
    final idx = storage.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      storage[idx] = event;
    }
    return event;
  }

  @override
  Future<void> deleteEvent(String id) async {
    storage.removeWhere((e) => e.id == id);
  }
}

class FakeTaskRepository implements TaskRepository {
  final List<Task> storage = [];

  @override
  Future<List<Task>> getTasks(String userId) async =>
      storage.where((t) => t.userId == userId).toList();

  @override
  Future<Task?> getTask(String id) async {
    final matches = storage.where((t) => t.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<Task> createTask(Task task) async {
    storage.insert(0, task);
    return task;
  }

  @override
  Future<Task> updateTask(Task task) async {
    final idx = storage.indexWhere((t) => t.id == task.id);
    if (idx != -1) storage[idx] = task;
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    storage.removeWhere((t) => t.id == id);
  }

  @override
  Future<Task> completeTask(String id) async {
    final idx = storage.indexWhere((t) => t.id == id);
    final updated = storage[idx].copyWith(completed: true);
    storage[idx] = updated;
    return updated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository authRepo;
  late FakeCalendarRepository calendarRepo;
  late FakeTaskRepository taskRepo;

  late AuthController authController;
  late TaskController taskController;
  late CalendarController calendarController;

  const testUser = AppUser(
    uid: 'u_test_1',
    email: 'user@omnilife.test',
    displayName: 'Test User',
  );

  setUp(() {
    Get.testMode = true;
    authRepo = FakeAuthRepository(testUser);
    calendarRepo = FakeCalendarRepository();
    taskRepo = FakeTaskRepository();

    authController = AuthController(authRepository: authRepo);
    taskController = TaskController(
      taskRepository: taskRepo,
      authController: authController,
    );
    calendarController = CalendarController(
      calendarRepository: calendarRepo,
      taskController: taskController,
      authController: authController,
    );
  });

  tearDown(() {
    Get.reset();
  });

  test('initial state defaults to month view and today date', () {
    expect(calendarController.viewMode.value, CalendarViewMode.month);
    expect(calendarController.isTodaySelected, isTrue);
  });

  test('changeViewMode updates view mode correctly', () {
    calendarController.changeViewMode(CalendarViewMode.week);
    expect(calendarController.viewMode.value, CalendarViewMode.week);

    calendarController.changeViewMode(CalendarViewMode.day);
    expect(calendarController.viewMode.value, CalendarViewMode.day);
  });

  test('selectDate updates selectedDate and focusedMonth', () {
    final target = DateTime(2026, 12, 25);
    calendarController.selectDate(target);

    expect(calendarController.selectedDate.value, target);
    expect(calendarController.focusedMonth.value.month, 12);
    expect(calendarController.isTodaySelected, isFalse);
  });

  test('jumpToToday resets selectedDate to today', () {
    calendarController.selectDate(DateTime(2025, 1, 1));
    expect(calendarController.isTodaySelected, isFalse);

    calendarController.jumpToToday();
    expect(calendarController.isTodaySelected, isTrue);
  });

  test('createEvent adds event optimistically and persists in repo', () async {
    final start = DateTime(2026, 10, 3, 14, 0);
    final end = DateTime(2026, 10, 3, 15, 0);

    final created = await calendarController.createEvent(
      title: 'Design Critique',
      startAt: start,
      endAt: end,
      colorTag: 'purple',
    );

    expect(created, isNotNull);
    expect(calendarController.events, hasLength(1));
    expect(calendarController.events.first.title, 'Design Critique');
    expect(calendarRepo.storage, hasLength(1));
  });

  test('updateEvent modifies event and updates list', () async {
    final start = DateTime(2026, 10, 3, 14, 0);
    final end = DateTime(2026, 10, 3, 15, 0);

    final created = await calendarController.createEvent(
      title: 'Original Title',
      startAt: start,
      endAt: end,
    );

    final updated = created!.copyWith(title: 'Updated Event Title');
    final saved = await calendarController.updateEvent(updated);

    expect(saved?.title, 'Updated Event Title');
    expect(calendarController.events.first.title, 'Updated Event Title');
  });

  test('deleteEvent removes event optimistically and from repository', () async {
    final start = DateTime(2026, 10, 3, 14, 0);
    final end = DateTime(2026, 10, 3, 15, 0);

    final created = await calendarController.createEvent(
      title: 'Quick Sync',
      startAt: start,
      endAt: end,
    );

    expect(calendarController.events, hasLength(1));

    final success = await calendarController.deleteEvent(created!.id);
    expect(success, isTrue);
    expect(calendarController.events, isEmpty);
    expect(calendarRepo.storage, isEmpty);
  });

  test('two-way link: tasks with due dates automatically appear in agenda', () async {
    final selectedDay = DateTime(2026, 10, 3);
    calendarController.selectDate(selectedDay);

    // Create a task due on that date
    await taskController.createTask(
      title: 'Review PR #42',
      dueDate: DateTime(2026, 10, 3, 16, 0),
    );

    // Check agendaForSelectedDate
    final agenda = calendarController.agendaForSelectedDate;
    expect(agenda, hasLength(1));
    expect(agenda.first.title, 'Review PR #42');
  });
}
