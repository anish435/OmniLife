import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reminder.dart';
import '../../repositories/reminder_repository.dart';
import '../../services/reminder_scheduler.dart';

/// Saves reminders through [ReminderRepository] and keeps their alerts in
/// step through a [ReminderScheduler]. The repository write comes first, so a
/// scheduling problem never loses the reminder.
class ReminderServiceImpl implements ReminderService {
  ReminderServiceImpl({
    required this.repository,
    required this.scheduler,
    required this.uidProvider,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4());

  final ReminderRepository repository;
  final ReminderScheduler scheduler;
  final String? Function() uidProvider;
  final DateTime Function() _now;
  final String Function() _newId;

  String _requireUid() {
    final uid = uidProvider();
    if (uid == null) {
      throw const AuthFailure('Sign in to save reminders.');
    }
    return uid;
  }

  @override
  Future<Reminder> create({
    required String title,
    required DateTime at,
    ReminderRepeat repeat = ReminderRepeat.none,
    String? note,
  }) async {
    final uid = _requireUid();
    final now = _now();
    final saved = await repository.create(
      Reminder(
        id: _newId(),
        userId: uid,
        title: title.trim(),
        scheduledAt: at,
        repeat: repeat,
        note: note,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await scheduler.schedule(saved);
    return saved;
  }

  @override
  Future<Reminder> update(Reminder reminder) async {
    final saved = await repository.update(reminder);
    await scheduler.schedule(saved);
    return saved;
  }

  @override
  Future<void> remove(Reminder reminder) async {
    await repository.delete(reminder);
    await scheduler.cancel(reminder.id);
  }

  @override
  Future<List<Reminder>> all() => repository.list(_requireUid());

  /// Re-registers every alert for [uid]. Called after sign-in and on app
  /// start so reminders survive restarts and reinstalls.
  Future<void> rescheduleAll(String uid) async {
    final reminders = await repository.list(uid);
    for (final r in reminders) {
      await scheduler.schedule(r);
    }
  }
}
