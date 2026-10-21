import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/calendar_event.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/life_event.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/wellness_log.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/repositories/life_event_repository.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/repositories/wellness_repository.dart';
import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/controllers/calendar_controller.dart';
import '../../presentation/controllers/finance_controller.dart';
import '../../presentation/controllers/habits_controller.dart';
import '../../presentation/controllers/notes_controller.dart';
import '../../presentation/controllers/pulse_controller.dart';
import '../../presentation/controllers/reminders_controller.dart';
import '../../presentation/controllers/task_controller.dart';
import '../../presentation/controllers/wellness_controller.dart';

/// Provides a complete, end-to-end dataset for evaluation, testing,
/// and live demonstration across all OmniLife modules, with support
/// for exiting testing mode and restoring the authentic user state.
class DemoDataSeeder {
  DemoDataSeeder._();

  static const String demoPrefix = 'omni_demo_';
  static const String _prefKey = 'omnilife_demo_mode_active';

  static final RxBool isDemoMode = false.obs;

  static const String signInMessage = 'Sign in to load sample data.';

  /// Plain reason the last [seedAll] / [clearDemoData] call did nothing.
  static String? lastError;

  static Future<void> checkStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        isDemoMode.value = saved;
        return;
      }
    } catch (_) {}

    // Fallback: detect if demo entities are present in active controllers
    try {
      if (Get.isRegistered<TaskController>()) {
        final hasDemo = Get.find<TaskController>().tasks.any(
          (t) => t.id.startsWith(demoPrefix) || _isDemoTaskTitle(t.title),
        );
        if (hasDemo) {
          isDemoMode.value = true;
          return;
        }
      }
      if (Get.isRegistered<FinanceController>()) {
        final hasDemo = Get.find<FinanceController>().transactions.any(
          (tx) => tx.id.startsWith(demoPrefix) || _isDemoFinanceTitle(tx.title),
        );
        if (hasDemo) {
          isDemoMode.value = true;
          return;
        }
      }
      if (Get.isRegistered<HabitsController>()) {
        final hasDemo = Get.find<HabitsController>().habits.any(
          (h) => h.id.startsWith(demoPrefix) || _isDemoHabitTitle(h.title),
        );
        if (hasDemo) {
          isDemoMode.value = true;
          return;
        }
      }
      if (Get.isRegistered<PulseController>()) {
        final pc = Get.find<PulseController>();
        if (pc.insights.value != null &&
            pc.insights.value!.patterns.isNotEmpty) {
          isDemoMode.value = true;
          return;
        }
      }
    } catch (_) {}
    isDemoMode.value = false;
  }

  static Future<bool> seedAll() async {
    try {
      final auth = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final uid = auth?.currentUser.value?.uid ?? '';
      if (uid.isEmpty) {
        lastError = signInMessage;
        return false;
      }
      lastError = null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final uuid = const Uuid();

      // 1. Seed Tasks
      if (Get.isRegistered<TaskRepository>()) {
        final taskRepo = Get.find<TaskRepository>();
        final tasks = [
          Task(
            id: '${demoPrefix}task_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Plan the week ahead',
            description:
                'Sort out work priorities and decide what to cook for dinner.',
            completed: false,
            priority: TaskPriority.high,
            dueDate: today.add(const Duration(hours: 17)),
            createdAt: now.subtract(const Duration(hours: 4)),
            updatedAt: now.subtract(const Duration(hours: 4)),
          ),
          Task(
            id: '${demoPrefix}task_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Return the library books',
            description: 'Due back by this evening.',
            completed: false,
            priority: TaskPriority.medium,
            dueDate: today.add(const Duration(hours: 19)),
            createdAt: now.subtract(const Duration(hours: 3)),
            updatedAt: now.subtract(const Duration(hours: 3)),
          ),
          Task(
            id: '${demoPrefix}task_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Water the plants',
            description: 'Did the balcony ones too.',
            completed: true,
            priority: TaskPriority.low,
            dueDate: today.add(const Duration(hours: 10)),
            createdAt: now.subtract(const Duration(hours: 6)),
            updatedAt: now.subtract(const Duration(hours: 1)),
          ),
          Task(
            id: '${demoPrefix}task_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Pick up organic groceries & matcha tea',
            description: 'Fruit, vegetables and milk.',
            completed: false,
            priority: TaskPriority.medium,
            dueDate: today.add(const Duration(days: 1, hours: 14)),
            createdAt: now.subtract(const Duration(hours: 2)),
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
          Task(
            id: '${demoPrefix}task_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Schedule annual dental checkup',
            description: 'Routine preventive care appointment.',
            completed: false,
            priority: TaskPriority.low,
            dueDate: today.add(const Duration(days: 3)),
            createdAt: now.subtract(const Duration(days: 1)),
            updatedAt: now.subtract(const Duration(days: 1)),
          ),
        ];

        for (final t in tasks) {
          try {
            await taskRepo.createTask(t);
          } catch (e) {
            debugPrint('Seed task error: $e');
          }
        }
      }

      // 2. Seed Calendar Events
      if (Get.isRegistered<CalendarRepository>()) {
        final calRepo = Get.find<CalendarRepository>();
        final events = [
          CalendarEvent(
            id: '${demoPrefix}event_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Morning coffee with Priya',
            description: 'A quick catch up before work.',
            startAt: today.add(const Duration(hours: 10)),
            endAt: today.add(const Duration(hours: 10, minutes: 30)),
            colorTag: 'blue',
            type: CalendarEventType.event,
            createdAt: now,
            updatedAt: now,
          ),
          CalendarEvent(
            id: '${demoPrefix}event_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Lunch with Mom',
            description: 'Her favourite place near the market.',
            startAt: today.add(const Duration(hours: 14)),
            endAt: today.add(const Duration(hours: 15, minutes: 30)),
            colorTag: 'purple',
            type: CalendarEventType.event,
            createdAt: now,
            updatedAt: now,
          ),
          CalendarEvent(
            id: '${demoPrefix}event_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Evening gym session',
            description: 'Cardio and some weights.',
            startAt: today.add(const Duration(hours: 18)),
            endAt: today.add(const Duration(hours: 19)),
            colorTag: 'green',
            type: CalendarEventType.event,
            createdAt: now,
            updatedAt: now,
          ),
          CalendarEvent(
            id: '${demoPrefix}event_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Weekend trip planning',
            description: 'Pick the dates and book the train.',
            startAt: today.add(const Duration(days: 1, hours: 11)),
            endAt: today.add(const Duration(days: 1, hours: 12)),
            colorTag: 'orange',
            type: CalendarEventType.event,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        for (final ev in events) {
          try {
            await calRepo.createEvent(ev);
          } catch (e) {
            debugPrint('Seed event error: $e');
          }
        }
      }

      // 3. Seed Habits and Daily Logs
      if (Get.isRegistered<HabitRepository>()) {
        final habitRepo = Get.find<HabitRepository>();
        final habits = [
          Habit(
            id: '${demoPrefix}habit_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Morning meditation',
            description: 'Ten quiet minutes before the day starts.',
            frequency: HabitFrequency.daily,
            targetDaysPerWeek: 7,
            specificDays: const [1, 2, 3, 4, 5, 6, 7],
            colorTag: 'teal',
            currentStreak: 6,
            longestStreak: 14,
            createdAt: now.subtract(const Duration(days: 14)),
            updatedAt: now,
          ),
          Habit(
            id: '${demoPrefix}habit_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Read 20 pages',
            description: 'A little every night before bed.',
            frequency: HabitFrequency.daily,
            targetDaysPerWeek: 7,
            specificDays: const [1, 2, 3, 4, 5, 6, 7],
            colorTag: 'indigo',
            currentStreak: 5,
            longestStreak: 12,
            createdAt: now.subtract(const Duration(days: 12)),
            updatedAt: now,
          ),
          Habit(
            id: '${demoPrefix}habit_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Drink 2.5 litres of water',
            description: 'Keep a bottle on the desk.',
            frequency: HabitFrequency.daily,
            targetDaysPerWeek: 7,
            specificDays: const [1, 2, 3, 4, 5, 6, 7],
            colorTag: 'blue',
            currentStreak: 7,
            longestStreak: 21,
            createdAt: now.subtract(const Duration(days: 21)),
            updatedAt: now,
          ),
          Habit(
            id: '${demoPrefix}habit_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Evening walk or jog',
            description: 'Some fresh air after dinner.',
            frequency: HabitFrequency.weekly,
            targetDaysPerWeek: 4,
            specificDays: const [1, 3, 5, 7],
            colorTag: 'amber',
            currentStreak: 3,
            longestStreak: 8,
            createdAt: now.subtract(const Duration(days: 30)),
            updatedAt: now,
          ),
        ];

        for (final h in habits) {
          try {
            await habitRepo.createHabit(h);
            // Log past days completions
            for (int i = 0; i < h.currentStreak; i++) {
              final d = today.subtract(Duration(days: i));
              final dateStr = DateFormat('yyyy-MM-dd').format(d);
              try {
                await habitRepo.toggleHabitLog(h.id, dateStr);
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('Seed habit error: $e');
          }
        }
      }

      // 4. Seed Finance Transactions
      if (Get.isRegistered<FinanceRepository>()) {
        final finRepo = Get.find<FinanceRepository>();
        final txs = [
          FinanceTransaction(
            id: '${demoPrefix}tx_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Freelance project payment',
            amount: 2500.0,
            category: TransactionCategory.income,
            isIncome: true,
            date: today.add(const Duration(hours: 9)),
            createdAt: now,
            updatedAt: now,
          ),
          FinanceTransaction(
            id: '${demoPrefix}tx_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Monthly salary',
            amount: 4200.0,
            category: TransactionCategory.income,
            isIncome: true,
            date: today.subtract(const Duration(days: 4)),
            createdAt: now.subtract(const Duration(days: 4)),
            updatedAt: now.subtract(const Duration(days: 4)),
          ),
          FinanceTransaction(
            id: '${demoPrefix}tx_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Grocery run',
            amount: 86.40,
            category: TransactionCategory.food,
            isIncome: false,
            date: today.add(const Duration(hours: 12)),
            createdAt: now,
            updatedAt: now,
          ),
          FinanceTransaction(
            id: '${demoPrefix}tx_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Coffee and breakfast',
            amount: 14.50,
            category: TransactionCategory.food,
            isIncome: false,
            date: today.add(const Duration(hours: 8, minutes: 30)),
            createdAt: now,
            updatedAt: now,
          ),
          FinanceTransaction(
            id: '${demoPrefix}tx_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Internet bill',
            amount: 85.00,
            category: TransactionCategory.utilities,
            isIncome: false,
            date: today.subtract(const Duration(days: 2)),
            createdAt: now.subtract(const Duration(days: 2)),
            updatedAt: now.subtract(const Duration(days: 2)),
          ),
          FinanceTransaction(
            id: '${demoPrefix}tx_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Gym membership',
            amount: 60.00,
            category: TransactionCategory.entertainment,
            isIncome: false,
            date: today.subtract(const Duration(days: 5)),
            createdAt: now.subtract(const Duration(days: 5)),
            updatedAt: now.subtract(const Duration(days: 5)),
          ),
        ];

        for (final tx in txs) {
          try {
            await finRepo.createTransaction(tx);
          } catch (e) {
            debugPrint('Seed finance error: $e');
          }
        }
      }

      // 5. Seed Notes
      if (Get.isRegistered<NoteRepository>()) {
        final noteRepo = Get.find<NoteRepository>();
        final notes = [
          Note(
            id: '${demoPrefix}note_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Plans for the next few months',
            content:
                '# Next few months\n\n'
                'Things I want to get done before the year ends.\n\n'
                '### Priorities\n'
                '- **Sleep**: aim for 11pm bedtime on weekdays\n'
                '- **Move**: walk or gym at least four times a week\n'
                '- **Money**: set aside a little every month\n\n'
                '- [x] Renew passport\n'
                '- [x] Book the dentist\n'
                '- [ ] Plan a trip with friends',
            category: 'Personal',
            colorTag: 'blue',
            isPinned: true,
            tags: const ['Goals', 'Planning'],
            createdAt: now.subtract(const Duration(days: 3)),
            updatedAt: now.subtract(const Duration(hours: 1)),
          ),
          Note(
            id: '${demoPrefix}note_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Weekly meal prep ideas',
            content:
                'Simple meals for the week:\n\n'
                '1. Wild salmon with roasted asparagus and quinoa\n'
                '2. Mediterranean lentil bowl with olive oil & feta\n'
                '3. Morning smoothie: blueberries, spinach, chia',
            category: 'Health',
            colorTag: 'green',
            isPinned: false,
            tags: const ['Food', 'Recipes'],
            createdAt: now.subtract(const Duration(days: 2)),
            updatedAt: now.subtract(const Duration(days: 2)),
          ),
          Note(
            id: '${demoPrefix}note_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Books and quotes to reflect on',
            content:
                '> "We are what we repeatedly do. Excellence, then, is not an act, but a habit."\n\n'
                'Key reads for this quarter:\n'
                '- Atomic Habits (James Clear)\n'
                '- Deep Work (Cal Newport)\n'
                '- Why We Sleep (Matthew Walker)',
            category: 'Personal',
            colorTag: 'amber',
            isPinned: false,
            tags: const ['Reading', 'Philosophy'],
            createdAt: now.subtract(const Duration(days: 5)),
            updatedAt: now.subtract(const Duration(days: 5)),
          ),
        ];

        for (final n in notes) {
          try {
            await noteRepo.createNote(n);
          } catch (e) {
            debugPrint('Seed note error: $e');
          }
        }
      }

      // 6. Seed Wellness Logs (12 days for rich charts, trend graphs & pattern detection)
      if (Get.isRegistered<WellnessRepository>()) {
        final wellRepo = Get.find<WellnessRepository>();
        for (int i = 0; i < 12; i++) {
          final d = today.subtract(Duration(days: i));
          final isHighSleepDay = i < 6;
          final log = WellnessLog(
            id: '${demoPrefix}well_${d.millisecondsSinceEpoch}',
            date: d,
            waterIntakeMl: isHighSleepDay ? 2500 : 1800,
            sleepDurationHours: isHighSleepDay ? 8.2 : 6.0,
            sleepQuality: isHighSleepDay ? 5 : 3,
            workoutDurationMinutes: isHighSleepDay ? 45 : 20,
            workoutType: isHighSleepDay ? 'Running' : 'Light Walk',
            moodScore: isHighSleepDay ? 5 : 3,
            synced: true,
          );
          try {
            await wellRepo.saveLog(uid, log);
          } catch (e) {
            debugPrint('Seed wellness error: $e');
          }
        }
      }

      // 7. Seed OmniPulse Life Events (for Momentum, Replay, and Pattern Insights)
      if (Get.isRegistered<LifeEventRepository>()) {
        final lifeRepo = Get.find<LifeEventRepository>();
        for (int i = 0; i < 12; i++) {
          final dayBase = today.subtract(Duration(days: i));
          final isHighSleepDay = i < 6;

          // Sleep start previous night
          await lifeRepo.record(
            uid,
            LifeEventType.sleepStart,
            at: dayBase.subtract(
              Duration(
                hours: isHighSleepDay ? 1 : 0,
                minutes: isHighSleepDay ? 30 : 0,
              ),
            ),
            metadata: {
              'isDemo': true,
              'omniDemo': true,
              'label': isHighSleepDay ? 'Deep Sleep' : 'Restless Sleep',
            },
          );
          // Wake up morning
          await lifeRepo.record(
            uid,
            LifeEventType.wake,
            at: dayBase.add(
              Duration(hours: isHighSleepDay ? 7 : 6, minutes: 0),
            ),
            metadata: {
              'isDemo': true,
              'omniDemo': true,
              'label': isHighSleepDay ? 'Refreshed Wakeup' : 'Early Alarm',
            },
          );
          // Morning water
          await lifeRepo.record(
            uid,
            LifeEventType.water,
            at: dayBase.add(const Duration(hours: 7, minutes: 30)),
            metadata: {
              'isDemo': true,
              'omniDemo': true,
              'ml': isHighSleepDay ? 500 : 250,
            },
          );
          // Focus session
          await lifeRepo.record(
            uid,
            LifeEventType.focus,
            at: dayBase.add(const Duration(hours: 10)),
            metadata: {
              'isDemo': true,
              'omniDemo': true,
              'minutes': isHighSleepDay ? 100 : 35,
              'label': isHighSleepDay ? 'Deep Work Sprint' : 'Quick Task',
            },
          );
          // Mood check-in
          await lifeRepo.record(
            uid,
            LifeEventType.mood,
            at: dayBase.add(const Duration(hours: 13)),
            metadata: {
              'isDemo': true,
              'omniDemo': true,
              'score': isHighSleepDay ? 5 : 3,
              'label': isHighSleepDay
                  ? 'Productive and energized'
                  : 'Slight fatigue',
            },
          );
          // Workout
          await lifeRepo.record(
            uid,
            LifeEventType.workout,
            at: dayBase.add(const Duration(hours: 17, minutes: 30)),
            metadata: {
              'isDemo': true,
              'omniDemo': true,
              'duration': isHighSleepDay ? 45 : 20,
              'type': isHighSleepDay ? 'Cardio & Strength' : 'Stretching',
            },
          );
        }
      }

      // 8. Seed Reminders
      if (Get.isRegistered<ReminderRepository>()) {
        final remRepo = Get.find<ReminderRepository>();
        final reminders = [
          Reminder(
            id: '${demoPrefix}rem_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Take afternoon stretch & hydrate break',
            scheduledAt: now.add(const Duration(minutes: 45)),
            repeat: ReminderRepeat.none,
            note: 'Walk for 5 minutes and drink water',
            createdAt: now,
            updatedAt: now,
          ),
          Reminder(
            id: '${demoPrefix}rem_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Evening reflection',
            scheduledAt: today.add(const Duration(hours: 21)),
            repeat: ReminderRepeat.daily,
            note: 'Write down three good things and look at tomorrow',
            createdAt: now,
            updatedAt: now,
          ),
          Reminder(
            id: '${demoPrefix}rem_${uuid.v4().substring(0, 8)}',
            userId: uid,
            title: 'Morning Vitamin D & Omega-3 supplement',
            scheduledAt: today.add(const Duration(hours: 8)),
            repeat: ReminderRepeat.none,
            note: 'Completed during breakfast',
            createdAt: now.subtract(const Duration(hours: 5)),
            updatedAt: now.subtract(const Duration(hours: 5)),
          ),
        ];

        for (final r in reminders) {
          try {
            await remRepo.create(r);
          } catch (e) {
            debugPrint('Seed reminder error: $e');
          }
        }
      }

      isDemoMode.value = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKey, true);
      } catch (_) {}

      _refreshControllers();

      return true;
    } catch (e, stack) {
      debugPrint('Error seeding demo data: $e\n$stack');
      return false;
    }
  }

  /// Cleans up seeded demo data and resets the workspace back to authentic user data.
  static Future<bool> clearDemoData() async {
    try {
      final auth = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      final uid = auth?.currentUser.value?.uid ?? '';
      if (uid.isEmpty) {
        lastError = signInMessage;
        return false;
      }
      lastError = null;
      final now = DateTime.now();

      // 1. Clear Tasks
      if (Get.isRegistered<TaskRepository>()) {
        final taskRepo = Get.find<TaskRepository>();
        try {
          final tasks = await taskRepo.getTasks(uid);
          for (final t in tasks) {
            if (t.id.startsWith(demoPrefix) || _isDemoTaskTitle(t.title)) {
              await taskRepo.deleteTask(t.id);
            }
          }
        } catch (e) {
          debugPrint('Clear tasks error: $e');
        }
      }

      // 2. Clear Calendar Events
      if (Get.isRegistered<CalendarRepository>()) {
        final calRepo = Get.find<CalendarRepository>();
        try {
          final events = await calRepo.getEventsForRange(
            uid,
            now.subtract(const Duration(days: 60)),
            now.add(const Duration(days: 60)),
          );
          for (final ev in events) {
            if (ev.id.startsWith(demoPrefix) || _isDemoEventTitle(ev.title)) {
              await calRepo.deleteEvent(ev.id);
            }
          }
        } catch (e) {
          debugPrint('Clear calendar error: $e');
        }
      }

      // 3. Clear Habits
      if (Get.isRegistered<HabitRepository>()) {
        final habitRepo = Get.find<HabitRepository>();
        try {
          final habits = await habitRepo.getHabits(uid);
          for (final h in habits) {
            if (h.id.startsWith(demoPrefix) || _isDemoHabitTitle(h.title)) {
              await habitRepo.deleteHabit(h.id);
            }
          }
        } catch (e) {
          debugPrint('Clear habits error: $e');
        }
      }

      // 4. Clear Finance Transactions
      if (Get.isRegistered<FinanceRepository>()) {
        final finRepo = Get.find<FinanceRepository>();
        try {
          final txs = await finRepo.getTransactions(uid);
          for (final tx in txs) {
            if (tx.id.startsWith(demoPrefix) || _isDemoFinanceTitle(tx.title)) {
              await finRepo.deleteTransaction(tx.id);
            }
          }
        } catch (e) {
          debugPrint('Clear finance error: $e');
        }
      }

      // 5. Clear Notes
      if (Get.isRegistered<NoteRepository>()) {
        final noteRepo = Get.find<NoteRepository>();
        try {
          final notes = await noteRepo.getNotes(uid);
          for (final n in notes) {
            if (n.id.startsWith(demoPrefix) || _isDemoNoteTitle(n.title)) {
              await noteRepo.deleteNote(n.id);
            }
          }
          final archived = await noteRepo.getArchivedNotes(uid);
          for (final n in archived) {
            if (n.id.startsWith(demoPrefix) || _isDemoNoteTitle(n.title)) {
              await noteRepo.deleteNote(n.id);
            }
          }
        } catch (e) {
          debugPrint('Clear notes error: $e');
        }
      }

      // 6. Clear Life Events
      if (Get.isRegistered<LifeEventRepository>()) {
        final lifeRepo = Get.find<LifeEventRepository>();
        try {
          final events = await lifeRepo.range(
            uid,
            now.subtract(const Duration(days: 60)),
            now.add(const Duration(days: 2)),
          );
          for (final ev in events) {
            final isDemo =
                ev.id.startsWith(demoPrefix) ||
                ev.metadata['omniDemo'] == true ||
                ev.metadata['isDemo'] == true ||
                _isDemoLifeEventLabel(ev.label);
            if (isDemo) {
              await lifeRepo.delete(ev);
            }
          }
        } catch (e) {
          debugPrint('Clear life events error: $e');
        }
      }

      // 7. Clear Reminders
      if (Get.isRegistered<ReminderRepository>()) {
        final remRepo = Get.find<ReminderRepository>();
        try {
          final reminders = await remRepo.list(uid);
          for (final r in reminders) {
            if (r.id.startsWith(demoPrefix) || _isDemoReminderTitle(r.title)) {
              await remRepo.delete(r);
            }
          }
        } catch (e) {
          debugPrint('Clear reminders error: $e');
        }
      }

      // Immediately purge in-memory lists for instant responsiveness
      if (Get.isRegistered<TaskController>()) {
        Get.find<TaskController>().tasks.removeWhere(
          (t) => t.id.startsWith(demoPrefix) || _isDemoTaskTitle(t.title),
        );
      }
      if (Get.isRegistered<CalendarController>()) {
        Get.find<CalendarController>().events.removeWhere(
          (e) => e.id.startsWith(demoPrefix) || _isDemoEventTitle(e.title),
        );
      }
      if (Get.isRegistered<HabitsController>()) {
        Get.find<HabitsController>().habits.removeWhere(
          (h) => h.id.startsWith(demoPrefix) || _isDemoHabitTitle(h.title),
        );
      }
      if (Get.isRegistered<FinanceController>()) {
        Get.find<FinanceController>().transactions.removeWhere(
          (tx) => tx.id.startsWith(demoPrefix) || _isDemoFinanceTitle(tx.title),
        );
      }
      if (Get.isRegistered<NotesController>()) {
        Get.find<NotesController>().notes.removeWhere(
          (n) => n.id.startsWith(demoPrefix) || _isDemoNoteTitle(n.title),
        );
        Get.find<NotesController>().archivedNotes.removeWhere(
          (n) => n.id.startsWith(demoPrefix) || _isDemoNoteTitle(n.title),
        );
      }
      if (Get.isRegistered<RemindersController>()) {
        Get.find<RemindersController>().reminders.removeWhere(
          (r) => r.id.startsWith(demoPrefix) || _isDemoReminderTitle(r.title),
        );
      }

      isDemoMode.value = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKey, false);
      } catch (_) {}

      _refreshControllers();

      return true;
    } catch (e, stack) {
      debugPrint('Error clearing demo data: $e\n$stack');
      return false;
    }
  }

  static void _refreshControllers() {
    if (Get.isRegistered<TaskController>()) {
      Get.find<TaskController>().loadTasks();
    }
    if (Get.isRegistered<CalendarController>()) {
      Get.find<CalendarController>().loadEvents();
    }
    if (Get.isRegistered<HabitsController>()) {
      Get.find<HabitsController>().loadHabits();
    }
    if (Get.isRegistered<FinanceController>()) {
      Get.find<FinanceController>().loadTransactions();
    }
    if (Get.isRegistered<NotesController>()) {
      Get.find<NotesController>().loadNotes();
    }
    if (Get.isRegistered<PulseController>()) {
      Get.find<PulseController>().loadDay();
      Get.find<PulseController>().loadInsights();
    }
    if (Get.isRegistered<RemindersController>()) {
      Get.find<RemindersController>().load();
    }
    if (Get.isRegistered<WellnessController>()) {
      Get.find<WellnessController>().changeDate(DateTime.now());
    }
  }

  static bool _isDemoTaskTitle(String title) {
    const titles = [
      'Prepare quarterly product roadmap presentation',
      'Review pull requests and run integration tests',
      'Morning briefing & team sync completed',
      'Pick up organic groceries & matcha tea',
      'Schedule annual dental checkup',
      'Review and approve pull request for OmniPulse v2',
      'Grocery shopping for weekly meal prep',
      'Deep work sprint on offline sync engine',
      'Pay quarterly tax estimate',
    ];
    final lower = title.toLowerCase();
    return titles.any(
      (t) => lower.contains(t.toLowerCase()) || t.toLowerCase().contains(lower),
    );
  }

  static bool _isDemoEventTitle(String title) {
    const titles = [
      'Daily Product Standup',
      'Architecture & AI Review',
      'Fitness & HIIT Workout',
      'Weekly Strategy Planning',
      'Product Strategy & Roadmap Sync',
      'OmniPulse V2 Technical Deep-Dive',
      'Dentist Checkup & Cleaning',
      'Weekly Family Dinner & Catchup',
    ];
    final lower = title.toLowerCase();
    return titles.any(
      (t) => lower.contains(t.toLowerCase()) || t.toLowerCase().contains(lower),
    );
  }

  static bool _isDemoHabitTitle(String title) {
    const titles = [
      'Morning Mindfulness & Meditation',
      'Read 20 Pages of Non-Fiction',
      'Hydration Target: 2.5 Liters',
      'Evening 5km Jog / Walk',
      'Drink 2.5L Water Daily',
      'Morning 30-min Cardio / Run',
      'Read 20 pages of nonfiction',
      'Nightly Gratitude & Reflection',
    ];
    final lower = title.toLowerCase();
    return titles.any(
      (t) => lower.contains(t.toLowerCase()) || t.toLowerCase().contains(lower),
    );
  }

  static bool _isDemoFinanceTitle(String title) {
    const titles = [
      'Enterprise Consulting Retainer',
      'Bi-Weekly Tech Salary',
      'Organic Food Market & Fresh Produce',
      'Specialty Espresso & Breakfast',
      'Fiber Internet & Cloud Services',
      'Fitness Club & Sauna Access',
      'Software Consulting Retainer',
      'Whole Foods Market',
      'AWS Cloud Infrastructure',
      'OmniGym Monthly Membership',
      'Blue Bottle Coffee',
      'Freelance Design Project',
    ];
    final lower = title.toLowerCase();
    return titles.any(
      (t) => lower.contains(t.toLowerCase()) || t.toLowerCase().contains(lower),
    );
  }

  static bool _isDemoNoteTitle(String title) {
    const titles = [
      'OmniLife Product Vision & Engineering Roadmap',
      'Weekly High-Performance Meal Prep',
      'Books & Quotes to Reflect On',
      'OmniLife Architecture & Offline-First Strategy',
      'Weekly Grocery & Meal Prep List',
      'Books to Read in 2026',
    ];
    final lower = title.toLowerCase();
    return titles.any(
      (t) => lower.contains(t.toLowerCase()) || t.toLowerCase().contains(lower),
    );
  }

  static bool _isDemoReminderTitle(String title) {
    const titles = [
      'Take afternoon stretch & hydrate break',
      'Daily Evening Life Reflection',
      'Morning Vitamin D & Omega-3 supplement',
    ];
    final lower = title.toLowerCase();
    return titles.any(
      (t) => lower.contains(t.toLowerCase()) || t.toLowerCase().contains(lower),
    );
  }

  static bool _isDemoLifeEventLabel(String? label) {
    if (label == null) return false;
    const labels = [
      'Deep Sleep',
      'Restless Sleep',
      'Refreshed Wakeup',
      'Early Alarm',
      'Deep Work Sprint',
      'Quick Task',
      'Productive and energized',
      'Slight fatigue',
      'Cardio & Strength',
      'Stretching',
    ];
    return labels.contains(label);
  }
}
