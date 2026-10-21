import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/reminder.dart';
import '../../domain/services/reminder_scheduler.dart';
import '../utils/reminder_text.dart';
import 'notification_routing.dart';
import 'notification_service.dart';

export '../../domain/services/reminder_scheduler.dart';

/// Phones and desktops: a local system notification at the right time, plus
/// foreground in-app alert when the app is active.
class NotificationReminderScheduler implements ReminderScheduler {
  NotificationReminderScheduler({
    NotificationService Function()? notifications,
    DateTime Function()? now,
    void Function(Reminder reminder)? onDue,
  }) : _notifications = notifications ?? (() => NotificationService.to),
       _now = now ?? DateTime.now,
       _inApp = onDue != null
           ? InAppReminderScheduler(onDue: onDue, now: now)
           : null;

  final NotificationService Function() _notifications;
  final DateTime Function() _now;
  final InAppReminderScheduler? _inApp;

  @override
  Future<void> schedule(Reminder reminder) async {
    final next = reminder.nextFire(_now());
    final id = reminderNotificationId(reminder.id);
    if (next == null) {
      await cancel(reminder.id);
      return;
    }
    if (_inApp != null) {
      await _inApp.schedule(reminder);
    }
    await _notifications().scheduleReminderNotification(
      id: id,
      title: reminder.title,
      body: (reminder.note?.trim().isNotEmpty ?? false)
          ? reminder.note!.trim()
          : describeReminderWhen(reminder, _now()),
      when: next,
      repeat: reminder.repeat,
      payload: NotificationRouting.encode(
        NotificationRouting.kindReminder,
        reminder.id,
      ),
    );
  }

  @override
  Future<void> cancel(String reminderId) async {
    if (_inApp != null) {
      await _inApp.cancel(reminderId);
    }
    await _notifications().cancelReminder(reminderNotificationId(reminderId));
  }
}

/// Web: scheduled notifications are not available, so while the app is open
/// a single timer wakes up at the next reminder and calls [onDue].
class InAppReminderScheduler implements ReminderScheduler {
  InAppReminderScheduler({
    required this.onDue,
    DateTime Function()? now,
    this.maxWait = const Duration(minutes: 15),
  }) : _now = now ?? DateTime.now;

  final void Function(Reminder reminder) onDue;
  final DateTime Function() _now;

  /// Longest sleep before re-checking, which also covers a laptop waking
  /// from sleep with the timer already overdue.
  final Duration maxWait;

  final Map<String, Reminder> _reminders = {};
  final Map<String, DateTime> _checkedFrom = {};
  Timer? _timer;

  @override
  Future<void> schedule(Reminder reminder) async {
    if (reminder.nextFire(_now()) == null) {
      await cancel(reminder.id);
      return;
    }
    _reminders[reminder.id] = reminder;
    _checkedFrom[reminder.id] = _now();
    _arm();
  }

  @override
  Future<void> cancel(String reminderId) async {
    _reminders.remove(reminderId);
    _checkedFrom.remove(reminderId);
    _arm();
  }

  /// Fires everything that came due since it was last checked.
  @visibleForTesting
  void tick() {
    final now = _now();
    for (final r in List.of(_reminders.values)) {
      final from = _checkedFrom[r.id] ?? now;
      final due = r.nextFire(from);
      if (due != null && !due.isAfter(now)) {
        _checkedFrom[r.id] = now;
        if (r.repeat == ReminderRepeat.none) _reminders.remove(r.id);
        onDue(r);
      }
    }
    _arm();
  }

  @visibleForTesting
  bool get isArmed => _timer != null;

  void _arm() {
    _timer?.cancel();
    _timer = null;
    final now = _now();
    DateTime? soonest;
    for (final r in _reminders.values) {
      final next = r.nextFire(_checkedFrom[r.id] ?? now);
      if (next != null && (soonest == null || next.isBefore(soonest))) {
        soonest = next;
      }
    }
    if (soonest == null) return;
    var wait = soonest.difference(now);
    if (wait.isNegative) wait = Duration.zero;
    if (wait > maxWait) wait = maxWait;
    _timer = Timer(wait, tick);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
