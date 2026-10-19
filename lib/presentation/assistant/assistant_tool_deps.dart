// Dependencies resolve lazily (Get.find) unless injected for tests.
// ignore_for_file: prefer_initializing_formals

import 'package:get/get.dart';

import '../../domain/repositories/finance_repository.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/usecases/pulse/pulse_insights_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/finance_controller.dart';
import '../controllers/habits_controller.dart';
import '../controllers/notes_controller.dart';
import '../controllers/pulse_controller.dart';
import '../controllers/task_controller.dart';

/// Resolves the app services the assistant's tools act through. Everything
/// is looked up lazily, so the assistant works as soon as a feature's
/// binding exists (for example Reminders) and tests can swap any piece.
class AssistantToolDeps {
  AssistantToolDeps({
    TaskController Function()? tasks,
    CalendarController Function()? calendar,
    NotesController Function()? notes,
    HabitsController Function()? habits,
    FinanceController Function()? finance,
    FinanceRepository Function()? financeRepository,
    PulseController Function()? pulse,
    PulseInsightsService Function()? insights,
    ReminderService? Function()? reminders,
    String? Function()? userId,
  }) : _tasks = tasks,
       _calendar = calendar,
       _notes = notes,
       _habits = habits,
       _finance = finance,
       _financeRepository = financeRepository,
       _pulse = pulse,
       _insights = insights,
       _reminders = reminders,
       _userId = userId;

  final TaskController Function()? _tasks;
  final CalendarController Function()? _calendar;
  final NotesController Function()? _notes;
  final HabitsController Function()? _habits;
  final FinanceController Function()? _finance;
  final FinanceRepository Function()? _financeRepository;
  final PulseController Function()? _pulse;
  final PulseInsightsService Function()? _insights;
  final ReminderService? Function()? _reminders;
  final String? Function()? _userId;

  TaskController get tasks =>
      (_tasks != null ? _tasks() : Get.find<TaskController>());
  CalendarController get calendar =>
      (_calendar != null ? _calendar() : Get.find<CalendarController>());
  NotesController get notes =>
      (_notes != null ? _notes() : Get.find<NotesController>());
  HabitsController get habits =>
      (_habits != null ? _habits() : Get.find<HabitsController>());
  FinanceController get finance =>
      (_finance != null ? _finance() : Get.find<FinanceController>());
  FinanceRepository get financeRepository => (_financeRepository != null
      ? _financeRepository()
      : Get.find<FinanceRepository>());
  PulseController get pulse =>
      (_pulse != null ? _pulse() : Get.find<PulseController>());
  PulseInsightsService get insights =>
      (_insights != null ? _insights() : Get.find<PulseInsightsService>());

  /// Null until the Reminders feature registers its [ReminderService].
  ReminderService? get reminders {
    if (_reminders != null) return _reminders();
    return Get.isRegistered<ReminderService>()
        ? Get.find<ReminderService>()
        : null;
  }

  String? get userId {
    if (_userId != null) return _userId();
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().currentUser.value?.uid;
  }
}
