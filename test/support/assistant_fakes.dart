import 'package:get/get.dart';
import 'package:omnilife/data/assistant/chat_history_store.dart';
import 'package:omnilife/domain/assistant/ai_provider.dart';
import 'package:omnilife/domain/assistant/assistant_engine.dart';
import 'package:omnilife/domain/assistant/assistant_tool.dart';
import 'package:omnilife/domain/entities/finance_transaction.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/entities/reminder.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/finance_repository.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/repositories/reminder_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';
import 'package:omnilife/presentation/assistant/assistant_tool_deps.dart';
import 'package:omnilife/presentation/assistant/assistant_tools.dart';
import 'package:omnilife/presentation/assistant/voice_service.dart';
import 'package:omnilife/presentation/controllers/assistant_controller.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/calendar_controller.dart';
import 'package:omnilife/presentation/controllers/finance_controller.dart';
import 'package:omnilife/presentation/controllers/habits_controller.dart';
import 'package:omnilife/presentation/controllers/notes_controller.dart';
import 'package:omnilife/presentation/controllers/pulse_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';

import '../presentation/controllers/calendar_controller_test.dart'
    show FakeCalendarRepository;
import '../presentation/controllers/task_controller_test.dart'
    show FakeAuthRepository, FakeTaskRepository;
import 'fake_habit_repositories.dart';
import 'fake_note_repository.dart';

/// Returns scripted responses and records what it was asked.
class FakeAiProvider implements AiProvider {
  FakeAiProvider(this.script, {this.configured = true});

  /// Builds the response for the latest user message.
  final AiResponse Function(String userText) script;
  final bool configured;
  final List<List<AiMessage>> requests = [];

  @override
  bool get isConfigured => configured;

  @override
  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  }) async {
    requests.add(messages);
    return script(messages.last.content);
  }
}

AiToolCall call(String name, Map<String, dynamic> args) =>
    AiToolCall(id: 'c_$name', name: name, arguments: args);

AiResponse calls(List<AiToolCall> c) => AiResponse(toolCalls: c);

class FakeReminderService implements ReminderService {
  final List<Reminder> store = [];
  var _seq = 0;

  @override
  Future<Reminder> create({
    required String title,
    required DateTime at,
    ReminderRepeat repeat = ReminderRepeat.none,
    String? note,
  }) async {
    final r = Reminder(
      id: 'r${++_seq}',
      userId: 'u1',
      title: title,
      scheduledAt: at,
      repeat: repeat,
      note: note,
      createdAt: at,
      updatedAt: at,
    );
    store.add(r);
    return r;
  }

  @override
  Future<Reminder> update(Reminder reminder) async => reminder;

  @override
  Future<void> remove(Reminder reminder) async {
    store.removeWhere((r) => r.id == reminder.id);
  }

  @override
  Future<List<Reminder>> all() async => [...store];
}

class FakeFinanceRepository implements FinanceRepository {
  final Map<String, FinanceTransaction> store = {};

  @override
  Future<List<FinanceTransaction>> getTransactions(
    String userId, {
    int? month,
    int? year,
  }) async => store.values
      .where(
        (t) =>
            t.userId == userId &&
            (month == null || t.date.month == month) &&
            (year == null || t.date.year == year),
      )
      .toList();

  @override
  Future<FinanceTransaction> createTransaction(FinanceTransaction t) async {
    store[t.id] = t;
    return t;
  }

  @override
  Future<FinanceTransaction> updateTransaction(FinanceTransaction t) async {
    store[t.id] = t;
    return t;
  }

  @override
  Future<void> deleteTransaction(String id) async => store.remove(id);
}

class FakeLifeEvents implements LifeEventRepository {
  final Map<String, LifeEvent> events = {};
  var _seq = 0;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  }) async {
    final now = at ?? DateTime(2026, 10, 19, 12);
    final e = LifeEvent(
      id: 'e${++_seq}',
      uid: uid,
      type: type,
      timestamp: now,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
    events[e.id] = e;
    return e;
  }

  @override
  Future<LifeEvent> update(LifeEvent event) async => events[event.id] = event;

  @override
  Future<void> delete(LifeEvent event) async => events.remove(event.id);

  @override
  Future<List<LifeEvent>> range(String uid, DateTime from, DateTime to) async =>
      events.values.toList();

  @override
  Future<void> refreshFromRemote(String uid, {int days = 90}) async {}
}

class FakeVoice implements VoiceService {
  VoiceIssue? startIssue;
  void Function(String)? onPartial;
  void Function(String)? onFinal;
  void Function(VoiceIssue)? onIssue;
  void Function()? onStopped;
  final spoken = <String>[];
  var starts = 0;
  var stops = 0;

  @override
  Future<VoiceIssue?> start({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(VoiceIssue issue) onIssue,
    void Function()? onStopped,
  }) async {
    starts++;
    if (startIssue != null) return startIssue;
    this.onPartial = onPartial;
    this.onFinal = onFinal;
    this.onIssue = onIssue;
    this.onStopped = onStopped;
    return null;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stopSpeaking() async {}
}

/// Real controllers over in-memory fakes, wired into an engine whose model
/// is scripted. No network, no key.
class AssistantHarness {
  AssistantHarness._();

  static const user = AppUser(uid: 'u1', email: 'a@b.c');

  late AuthController auth;
  late FakeTaskRepository taskRepo;
  late TaskController tasks;
  late FakeCalendarRepository calendarRepo;
  late CalendarController calendar;
  late FakeNoteRepository noteRepo;
  late NotesController notes;
  late FakeHabitRepository habitRepo;
  late HabitsController habits;
  late FakeFinanceRepository financeRepo;
  late FinanceController finance;
  late FakeLifeEvents lifeEvents;
  late PulseController pulse;
  late FakeReminderService reminders;
  late AssistantToolDeps deps;
  late AssistantEngine engine;
  late FakeAiProvider provider;
  late DateTime now;

  static Future<AssistantHarness> create({
    required AiResponse Function(String userText) script,
    DateTime? now,
    bool configured = true,
    bool withReminders = true,
  }) async {
    final h = AssistantHarness._();
    Get.testMode = true;
    Get.reset();
    h.now = now ?? DateTime(2026, 10, 19, 14, 5); // a Monday
    final clock = h.now;

    final authRepo = FakeAuthRepository(user);
    h.auth = AuthController(authRepository: authRepo)..onInit();
    await Future<void>.delayed(Duration.zero);
    Get.put<AuthController>(h.auth);

    h.taskRepo = FakeTaskRepository();
    h.tasks = TaskController(taskRepository: h.taskRepo, authController: h.auth)
      ..onInit();
    h.calendarRepo = FakeCalendarRepository();
    h.calendar = CalendarController(
      calendarRepository: h.calendarRepo,
      taskController: h.tasks,
      authController: h.auth,
    )..onInit();
    h.noteRepo = FakeNoteRepository();
    h.notes = NotesController(
      noteRepository: h.noteRepo,
      authController: h.auth,
    )..onInit();
    h.habitRepo = FakeHabitRepository();
    h.habits = HabitsController(
      habitRepository: h.habitRepo,
      authController: h.auth,
      clock: () => clock,
    )..onInit();

    // Let the controllers' initial loads finish before tests add data.
    await Future<void>.delayed(Duration.zero);

    h.financeRepo = FakeFinanceRepository();
    Get.put<FinanceRepository>(h.financeRepo);
    h.finance = Get.put<FinanceController>(FinanceController());

    await Future<void>.delayed(Duration.zero);

    h.lifeEvents = FakeLifeEvents();
    h.pulse = PulseController(
      service: PulseService(events: h.lifeEvents, now: () => clock),
      events: h.lifeEvents,
      uidProvider: () => user.uid,
      now: () => clock,
    );
    h.reminders = FakeReminderService();

    h.deps = AssistantToolDeps(
      tasks: () => h.tasks,
      calendar: () => h.calendar,
      notes: () => h.notes,
      habits: () => h.habits,
      finance: () => h.finance,
      financeRepository: () => h.financeRepo,
      pulse: () => h.pulse,
      reminders: () => withReminders ? h.reminders : null,
      userId: () => user.uid,
    );
    h.provider = FakeAiProvider(script, configured: configured);
    h.engine = AssistantEngine(
      provider: h.provider,
      tools: ToolRegistry(buildAssistantTools(h.deps)),
      now: () => clock,
    );
    return h;
  }

  AssistantController controller({VoiceService? voice}) => AssistantController(
    engine: engine,
    voice: voice ?? FakeVoice(),
    history: InMemoryChatHistoryStore(),
    uidProvider: () => user.uid,
    now: () => now,
    voiceStopGrace: Duration.zero,
  );
}
