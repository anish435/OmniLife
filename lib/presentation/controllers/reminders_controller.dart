// Dependencies are resolved lazily (Get.find) unless injected for tests,
// hence the private-named copies.
// ignore_for_file: prefer_initializing_formals

import 'package:get/get.dart';

import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import 'auth_controller.dart';

/// State for the Reminders screen. All saving goes through
/// [ReminderService], which also schedules the alerts.
class RemindersController extends GetxController {
  RemindersController({
    ReminderService? service,
    String? Function()? uidProvider,
    DateTime Function()? now,
  }) : _service = service,
       _uidProvider = uidProvider,
       _now = now ?? DateTime.now;

  ReminderService? _service;
  final String? Function()? _uidProvider;
  final DateTime Function() _now;

  ReminderService get service => _service ??= Get.find<ReminderService>();

  final reminders = <Reminder>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  Worker? _authWorker;

  DateTime get now => _now();

  String? get uid => _uidProvider != null
      ? _uidProvider()
      : (Get.isRegistered<AuthController>()
            ? Get.find<AuthController>().currentUser.value?.uid
            : null);

  @override
  void onInit() {
    super.onInit();
    if (_uidProvider == null && Get.isRegistered<AuthController>()) {
      _authWorker = ever(Get.find<AuthController>().currentUser, (user) {
        if (user != null) load();
      });
    }
    load();
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    super.onClose();
  }

  /// One-off reminders that are still ahead, soonest first.
  List<Reminder> get upcoming {
    final t = now;
    return reminders
        .where(
          (r) => r.repeat == ReminderRepeat.none && r.scheduledAt.isAfter(t),
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Daily and weekly reminders (paused ones included), by next time.
  List<Reminder> get repeating {
    final t = now;
    DateTime key(Reminder r) =>
        r.nextFire(t) ?? DateTime.fromMillisecondsSinceEpoch(1 << 50);
    return reminders.where((r) => r.repeat != ReminderRepeat.none).toList()
      ..sort((a, b) => key(a).compareTo(key(b)));
  }

  /// One-off reminders whose time has passed, most recent first.
  List<Reminder> get done {
    final t = now;
    return reminders
        .where(
          (r) => r.repeat == ReminderRepeat.none && !r.scheduledAt.isAfter(t),
        )
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  Future<void> load() async {
    final id = uid;
    if (id == null) return;
    isLoading.value = reminders.isEmpty;
    error.value = null;
    try {
      reminders.assignAll(await service.all());
    } catch (e) {
      error.value = 'Could not load your reminders. Pull down to try again.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Creates a reminder, or updates [existing]. Returns an error message for
  /// the form, or null on success.
  Future<String?> save({
    Reminder? existing,
    required String title,
    required DateTime at,
    required ReminderRepeat repeat,
  }) async {
    final name = title.trim();
    if (name.isEmpty) return 'Give your reminder a name.';
    if (repeat == ReminderRepeat.none &&
        !at.isAfter(now) &&
        (existing == null || existing.scheduledAt != at)) {
      return 'Pick a time that has not passed yet.';
    }
    try {
      if (existing == null) {
        final created = await service.create(
          title: name,
          at: at,
          repeat: repeat,
        );
        reminders.add(created);
      } else {
        final updated = await service.update(
          existing.copyWith(title: name, scheduledAt: at, repeat: repeat),
        );
        _replace(updated);
      }
      return null;
    } catch (e) {
      return 'Could not save that. Please try again.';
    }
  }

  Future<void> setEnabled(Reminder reminder, bool enabled) async {
    final previous = reminder;
    _replace(reminder.copyWith(enabled: enabled));
    try {
      _replace(await service.update(reminder.copyWith(enabled: enabled)));
    } catch (e) {
      _replace(previous);
      error.value = 'Could not change that reminder.';
    }
  }

  Future<void> delete(Reminder reminder) async {
    reminders.removeWhere((r) => r.id == reminder.id);
    try {
      await service.remove(reminder);
    } catch (e) {
      reminders.add(reminder);
      error.value = 'Could not delete that reminder.';
    }
  }

  /// Brings a just-deleted reminder back with the same id.
  Future<void> undoDelete(Reminder reminder) async {
    try {
      final restored = await service.update(reminder);
      reminders.removeWhere((r) => r.id == restored.id);
      reminders.add(restored);
    } catch (e) {
      error.value = 'Could not restore that reminder.';
    }
  }

  void _replace(Reminder r) {
    final i = reminders.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      reminders[i] = r;
    } else {
      reminders.add(r);
    }
  }
}
