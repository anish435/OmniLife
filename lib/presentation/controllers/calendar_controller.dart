import 'package:get/get.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/repositories/auth_repository.dart' show AppUser;
import '../../domain/repositories/calendar_repository.dart';
import '../../domain/usecases/calendar/get_agenda_for_range.dart';
import 'auth_controller.dart';
import 'task_controller.dart';

enum CalendarViewMode { month, week, day }

/// Presentation-layer state for Calendar and Schedule management.
class CalendarController extends GetxController {
  CalendarController({
    CalendarRepository? calendarRepository,
    TaskController? taskController,
    AuthController? authController,
    GetAgendaForRange? agendaUseCase,
  })  : _injectedRepository = calendarRepository,
        _injectedTaskController = taskController,
        _injectedAuthController = authController,
        _agendaUseCase = agendaUseCase ?? const GetAgendaForRange();

  final CalendarRepository? _injectedRepository;
  final TaskController? _injectedTaskController;
  final AuthController? _injectedAuthController;
  final GetAgendaForRange _agendaUseCase;

  CalendarRepository get _calendarRepository =>
      _injectedRepository ?? Get.find<CalendarRepository>();
  TaskController get _taskController =>
      _injectedTaskController ?? Get.find<TaskController>();
  AuthController get _authController =>
      _injectedAuthController ?? Get.find<AuthController>();

  final selectedDate = DateTime.now().obs;
  final focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1).obs;
  final viewMode = CalendarViewMode.month.obs;

  final events = <CalendarEvent>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  String get _currentUserId =>
      _authController.currentUser.value?.uid ?? 'guest-user';

  @override
  void onInit() {
    super.onInit();

    // Reload when user signs in or out
    ever<AppUser?>(_authController.currentUser, (user) {
      if (user != null) {
        loadEvents();
      } else {
        events.clear();
      }
    });

    if (_authController.currentUser.value != null) {
      loadEvents();
    }
  }

  bool get isTodaySelected {
    final now = DateTime.now();
    final d = selectedDate.value;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> loadEvents() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      // Load a wide window around focusedMonth (3 months backward and forward)
      final center = focusedMonth.value;
      final start = DateTime(center.year, center.month - 2, 1);
      final end = DateTime(center.year, center.month + 3, 0, 23, 59, 59);

      final loaded = await _calendarRepository.getEventsForRange(
        _currentUserId,
        start,
        end,
      );
      events.assignAll(loaded);
    } on Failure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Failed to load calendar: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void jumpToToday() {
    final now = DateTime.now();
    selectedDate.value = now;
    focusedMonth.value = DateTime(now.year, now.month, 1);
  }

  void selectDate(DateTime date) {
    selectedDate.value = date;
    if (date.month != focusedMonth.value.month || date.year != focusedMonth.value.year) {
      focusedMonth.value = DateTime(date.year, date.month, 1);
    }
  }

  void changeViewMode(CalendarViewMode mode) {
    viewMode.value = mode;
  }

  void previousPeriod() {
    switch (viewMode.value) {
      case CalendarViewMode.month:
        final current = focusedMonth.value;
        focusedMonth.value = DateTime(current.year, current.month - 1, 1);
        selectedDate.value = DateTime(
          focusedMonth.value.year,
          focusedMonth.value.month,
          selectedDate.value.day.clamp(
            1,
            DateTime(focusedMonth.value.year, focusedMonth.value.month + 1, 0).day,
          ),
        );
        loadEvents();
        break;
      case CalendarViewMode.week:
        selectedDate.value = selectedDate.value.subtract(const Duration(days: 7));
        if (selectedDate.value.month != focusedMonth.value.month) {
          focusedMonth.value = DateTime(selectedDate.value.year, selectedDate.value.month, 1);
          loadEvents();
        }
        break;
      case CalendarViewMode.day:
        selectedDate.value = selectedDate.value.subtract(const Duration(days: 1));
        if (selectedDate.value.month != focusedMonth.value.month) {
          focusedMonth.value = DateTime(selectedDate.value.year, selectedDate.value.month, 1);
          loadEvents();
        }
        break;
    }
  }

  void nextPeriod() {
    switch (viewMode.value) {
      case CalendarViewMode.month:
        final current = focusedMonth.value;
        focusedMonth.value = DateTime(current.year, current.month + 1, 1);
        selectedDate.value = DateTime(
          focusedMonth.value.year,
          focusedMonth.value.month,
          selectedDate.value.day.clamp(
            1,
            DateTime(focusedMonth.value.year, focusedMonth.value.month + 1, 0).day,
          ),
        );
        loadEvents();
        break;
      case CalendarViewMode.week:
        selectedDate.value = selectedDate.value.add(const Duration(days: 7));
        if (selectedDate.value.month != focusedMonth.value.month) {
          focusedMonth.value = DateTime(selectedDate.value.year, selectedDate.value.month, 1);
          loadEvents();
        }
        break;
      case CalendarViewMode.day:
        selectedDate.value = selectedDate.value.add(const Duration(days: 1));
        if (selectedDate.value.month != focusedMonth.value.month) {
          focusedMonth.value = DateTime(selectedDate.value.year, selectedDate.value.month, 1);
          loadEvents();
        }
        break;
    }
  }

  /// Merged agenda (Events + Tasks with due date) for [selectedDate].
  List<AgendaItem> get agendaForSelectedDate {
    final d = selectedDate.value;
    final dayStart = DateTime(d.year, d.month, d.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _agendaUseCase.call(
      events: events,
      tasks: _taskController.tasks,
      start: dayStart,
      end: dayEnd,
    );
  }

  /// Events for a specific day.
  List<CalendarEvent> eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return events.where((e) {
      return e.startAt.isBefore(dayEnd) && e.endAt.isAfter(dayStart);
    }).toList();
  }

  /// Side-by-side packed column layouts for Day and Week timelines.
  List<PositionedEventLayout> overlapLayoutForDay(DateTime day) {
    return _agendaUseCase.packDayEvents(events, day);
  }

  /// Returns the single next upcoming event from now onwards (for dashboard strip).
  CalendarEvent? get nextUpEvent {
    final now = DateTime.now();
    final upcoming = events.where((e) => e.endAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Future<CalendarEvent?> createEvent({
    required String title,
    String? description,
    required DateTime startAt,
    required DateTime endAt,
    bool isAllDay = false,
    String colorTag = 'blue',
    CalendarEventType type = CalendarEventType.event,
    String? linkedTaskId,
  }) async {
    if (title.trim().isEmpty) return null;
    if (endAt.isBefore(startAt)) return null;

    final now = DateTime.now();
    final newEvent = CalendarEvent(
      id: 'event_${now.millisecondsSinceEpoch}_${now.microsecond}',
      userId: _currentUserId,
      title: title.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      startAt: startAt,
      endAt: endAt,
      isAllDay: isAllDay,
      colorTag: colorTag,
      type: type,
      linkedTaskId: linkedTaskId,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic local add
    events.add(newEvent);
    events.sort((a, b) => a.startAt.compareTo(b.startAt));

    try {
      final created = await _calendarRepository.createEvent(newEvent);
      final idx = events.indexWhere((e) => e.id == newEvent.id);
      if (idx != -1) {
        events[idx] = created;
      }
      return created;
    } catch (e) {
      events.removeWhere((e) => e.id == newEvent.id);
      errorMessage.value = 'Failed to create event: $e';
      return null;
    }
  }

  Future<CalendarEvent?> updateEvent(CalendarEvent updated) async {
    final oldIndex = events.indexWhere((e) => e.id == updated.id);
    if (oldIndex == -1) return null;

    final previous = events[oldIndex];
    events[oldIndex] = updated;
    events.sort((a, b) => a.startAt.compareTo(b.startAt));

    try {
      final saved = await _calendarRepository.updateEvent(updated);
      final idx = events.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        events[idx] = saved;
      }
      return saved;
    } catch (e) {
      events[oldIndex] = previous;
      errorMessage.value = 'Failed to update event: $e';
      return null;
    }
  }

  Future<bool> deleteEvent(String id) async {
    final oldIndex = events.indexWhere((e) => e.id == id);
    if (oldIndex == -1) return false;

    final previous = events[oldIndex];
    events.removeAt(oldIndex);

    try {
      await _calendarRepository.deleteEvent(id);
      return true;
    } catch (e) {
      events.insert(oldIndex, previous);
      errorMessage.value = 'Failed to delete event: $e';
      return false;
    }
  }

  Future<void> toggleTask(String taskId) async {
    await _taskController.toggleTask(taskId);
  }
}
