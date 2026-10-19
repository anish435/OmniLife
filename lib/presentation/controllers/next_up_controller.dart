// Dependencies resolve lazily (Get.find) unless injected for tests.
// ignore_for_file: prefer_initializing_formals

import 'package:get/get.dart';

import '../../domain/entities/habit.dart';
import '../../domain/entities/life_event.dart';
import '../../domain/insights/next_up.dart';
import '../../domain/services/pulse/daily_facts.dart' show dayOf;
import 'auth_controller.dart';
import 'habits_controller.dart';
import 'pulse_controller.dart';
import 'reminders_controller.dart';
import 'task_controller.dart';

/// Feeds the "Next up" section. It reads today's tasks, habits, reminders
/// and Pulse events straight from the controllers the screens already use,
/// so the list refreshes whenever they change, and remembers (on this
/// device only) which hints were dismissed or acted on today.
class NextUpController extends GetxController {
  NextUpController({
    NextUpStore? store,
    NextUpEngine engine = const NextUpEngine(),
    String? Function()? uidProvider,
    DateTime Function()? now,
    TaskController? Function()? tasks,
    HabitsController? Function()? habits,
    RemindersController? Function()? reminders,
    PulseController? Function()? pulse,
  }) : _store = store,
       _engine = engine,
       _uidProvider = uidProvider,
       _now = now ?? DateTime.now,
       _tasks = tasks,
       _habits = habits,
       _reminders = reminders,
       _pulse = pulse;

  NextUpStore? _store;
  final NextUpEngine _engine;
  final String? Function()? _uidProvider;
  final DateTime Function() _now;
  final TaskController? Function()? _tasks;
  final HabitsController? Function()? _habits;
  final RemindersController? Function()? _reminders;
  final PulseController? Function()? _pulse;

  NextUpStore get store => _store ??= InMemoryNextUpStore();

  /// Hints dismissed or acted on today.
  final suppressed = <String>{}.obs;

  /// Bumped to re-evaluate time-based hints.
  final tick = 0.obs;

  String? _loadedFor;

  DateTime get now => _now();

  String get _uid {
    final id = _uidProvider != null
        ? _uidProvider()
        : (Get.isRegistered<AuthController>()
              ? Get.find<AuthController>().currentUser.value?.uid
              : null);
    return (id == null || id.isEmpty) ? 'guest' : id;
  }

  String _key() {
    final d = dayOf(now);
    return '$_uid|${d.year}-${d.month}-${d.day}';
  }

  /// Loads today's dismissals once per user and day.
  Future<void> ensureLoaded() async {
    final key = _key();
    if (_loadedFor == key) return;
    _loadedFor = key;
    Set<String> saved;
    try {
      saved = await store.load(_uid, now);
    } catch (_) {
      saved = {};
    }
    suppressed.assignAll(saved);
  }

  /// Hides a hint for the rest of today.
  Future<void> dismiss(String id) async {
    suppressed.add(id);
    try {
      await store.add(_uid, now, id);
    } catch (_) {
      // Hidden for this session at least.
    }
  }

  /// Same as [dismiss]: acting on a hint counts as having seen it.
  Future<void> acted(String id) => dismiss(id);

  /// The hints to show right now. Reads the controllers' observables, so
  /// calling this inside an `Obx` keeps it current.
  List<NextUpItem> get items {
    final _ = tick.value;
    if (_loadedFor != _key()) ensureLoaded();
    return _engine.compute(_input(), suppressed: suppressed.toSet());
  }

  NextUpInput _input() {
    final t = now;
    final today = dayOf(t);

    var tasksOpen = 0;
    final tasks = _resolve(_tasks, () => Get.find<TaskController>());
    if (tasks != null) {
      tasksOpen = tasks.todayTasks.where((x) => !x.completed).length;
    }

    var habitsLeft = 0;
    final habits = _resolve(_habits, () => Get.find<HabitsController>());
    if (habits != null) {
      for (final h in habits.habits) {
        if (_scheduledToday(h, today) && !habits.isHabitCompleted(h.id, t)) {
          habitsLeft++;
        }
      }
    }

    final upcoming = <UpcomingReminder>[];
    final reminders = _resolve(
      _reminders,
      () => Get.find<RemindersController>(),
    );
    if (reminders != null) {
      for (final r in reminders.reminders) {
        final next = r.nextFire(t);
        if (next != null && dayOf(next) == today) {
          upcoming.add(UpcomingReminder(id: r.id, title: r.title, at: next));
        }
      }
    }

    var pulseKnown = false;
    DateTime? lastWater;
    DateTime? lastMeal;
    var meals = 0;
    final pulse = _resolve(_pulse, () => Get.find<PulseController>());
    final view = pulse?.dayView.value;
    if (view != null && dayOf(view.day) == today) {
      pulseKnown = true;
      for (final e in view.events) {
        if (dayOf(e.timestamp) != today) continue;
        if (e.type == LifeEventType.water &&
            (lastWater == null || e.timestamp.isAfter(lastWater))) {
          lastWater = e.timestamp;
        }
        if (e.type == LifeEventType.meal) {
          meals++;
          if (lastMeal == null || e.timestamp.isAfter(lastMeal)) {
            lastMeal = e.timestamp;
          }
        }
      }
    }

    return NextUpInput(
      now: t,
      tasksOpen: tasksOpen,
      habitsLeft: habitsLeft,
      reminders: upcoming,
      pulseKnown: pulseKnown,
      lastWaterAt: lastWater,
      mealsToday: meals,
      lastMealAt: lastMeal,
    );
  }

  /// An injected controller, else a registered one, else null (the hint
  /// for that area is simply skipped).
  T? _resolve<T>(T? Function()? injected, T Function() find) {
    try {
      if (injected != null) return injected();
      return Get.isRegistered<T>() ? find() : null;
    } catch (_) {
      return null;
    }
  }

  bool _scheduledToday(Habit h, DateTime today) {
    if (today.isBefore(dayOf(h.createdAt))) return false;
    switch (h.frequency) {
      case HabitFrequency.daily:
        return true;
      case HabitFrequency.specificDays:
        return h.specificDays.contains(today.weekday);
      case HabitFrequency.weekly:
        return false;
    }
  }
}
