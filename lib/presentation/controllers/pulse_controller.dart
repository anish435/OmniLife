// Dependencies are resolved lazily (Get.find) unless injected for tests,
// hence the private-named copies.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:get/get.dart';

import '../../core/sync/sync_engine.dart';
import '../../domain/entities/life_event.dart';
import '../../domain/repositories/life_event_repository.dart';
import '../../domain/services/pulse/daily_facts.dart';
import '../../domain/usecases/pulse/pulse_insights_service.dart';
import '../../domain/usecases/pulse/pulse_service.dart';
import 'auth_controller.dart';

/// State for OmniPulse: the open sleep, the selected day's timeline and
/// replay, and the Momentum/Patterns insights. All capture goes through
/// [PulseService]; this controller only holds state and reloads it.
class PulseController extends GetxController {
  PulseController({
    PulseService? service,
    PulseInsightsService? insights,
    LifeEventRepository? events,
    String? Function()? uidProvider,
    DateTime Function()? now,
  }) : _service = service,
       _insights = insights,
       _events = events,
       _uidProvider = uidProvider,
       _now = now ?? DateTime.now;

  PulseService? _service;
  PulseInsightsService? _insights;
  LifeEventRepository? _events;
  final String? Function()? _uidProvider;
  final DateTime Function() _now;

  PulseService get service => _service ??= Get.find<PulseService>();
  PulseInsightsService get insightsService =>
      _insights ??= Get.find<PulseInsightsService>();
  LifeEventRepository get events => _events ??= Get.find<LifeEventRepository>();

  final selectedDay = DateTime.now().obs;
  final dayView = Rxn<DayView>();
  final openSleep = Rxn<LifeEvent>();
  final isLoading = false.obs;
  final error = RxnString();

  final insights = Rxn<PulseInsights>();
  final insightsLoading = false.obs;
  final insightsError = RxnString();

  StreamSubscription<void>? _sub;
  Worker? _authWorker;
  Timer? _debounce;

  String? get uid => _uidProvider != null
      ? _uidProvider()
      : (Get.isRegistered<AuthController>()
            ? Get.find<AuthController>().currentUser.value?.uid
            : null);

  bool get isToday {
    final d = selectedDay.value;
    return dayOf(d) == dayOf(_now());
  }

  @override
  void onInit() {
    super.onInit();
    selectedDay.value = dayOf(_now());
    try {
      _sub = events.changes.listen((_) => _scheduleReload());
    } catch (_) {
      // Repository not registered (tests that only use explicit loads).
    }
    if (Get.isRegistered<AuthController>()) {
      // When a user signs in, merge their cloud history and push anything
      // queued while signed out.
      _authWorker = ever(Get.find<AuthController>().currentUser, (user) {
        final id = user?.uid;
        if (id == null) return;
        events.refreshFromRemote(id);
        if (Get.isRegistered<SyncEngine>()) Get.find<SyncEngine>().flush();
        loadDay();
        refreshOpenSleep();
      });
    }
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      loadDay();
      refreshOpenSleep();
    });
  }

  Future<void> loadDay([DateTime? day]) async {
    final id = uid;
    if (day != null) selectedDay.value = dayOf(day);
    if (id == null) return;
    isLoading.value = dayView.value == null;
    error.value = null;
    try {
      dayView.value = await insightsService.dayView(id, selectedDay.value);
    } catch (e) {
      error.value = 'Could not load this day. Pull to retry.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshOpenSleep() async {
    final id = uid;
    if (id == null) return;
    try {
      openSleep.value = await service.openSleep(id);
    } catch (_) {
      openSleep.value = null;
    }
  }

  Future<void> loadInsights() async {
    final id = uid;
    if (id == null) return;
    insightsLoading.value = true;
    insightsError.value = null;
    try {
      insights.value = await insightsService.load(id);
    } catch (e) {
      insightsError.value = 'Could not load insights right now.';
    } finally {
      insightsLoading.value = false;
    }
  }

  void previousDay() =>
      loadDay(selectedDay.value.subtract(const Duration(days: 1)));

  void nextDay() {
    if (isToday) return;
    final d = selectedDay.value;
    loadDay(DateTime(d.year, d.month, d.day + 1));
  }

  void goToday() => loadDay(_now());

  /// Looks an event up by id in the last 90 days (for editing a sleep
  /// session's bedtime or wake time).
  Future<LifeEvent?> findEvent(String id) async {
    final userId = uid;
    if (userId == null) return null;
    final now = _now();
    final all = await events.range(
      userId,
      now.subtract(const Duration(days: 90)),
      now.add(const Duration(days: 1)),
    );
    return all.where((e) => e.id == id).firstOrNull;
  }

  // ---- one-tap capture -------------------------------------------------

  Future<QuickLogResult?> log(
    LifeEventType type, {
    Map<String, dynamic> metadata = const {},
  }) => _run(() => service.log(uid!, type, metadata: metadata));

  Future<QuickLogResult?> startSleep() => _run(() => service.startSleep(uid!));

  Future<QuickLogResult?> wake() => _run(() => service.wake(uid!));

  Future<void> undo(LifeEvent event) async {
    await _run(() async {
      await service.undo(event);
      return QuickLogResult(event: event);
    });
  }

  Future<void> correctTime(LifeEvent event, DateTime time) => _run(() async {
    await service.correctTime(event, time);
    return QuickLogResult(event: event);
  });

  Future<QuickLogResult?> _run(Future<QuickLogResult> Function() action) async {
    if (uid == null) {
      error.value = 'Sign in to record moments.';
      return null;
    }
    try {
      final result = await action();
      await Future.wait([loadDay(), refreshOpenSleep()]);
      return result;
    } catch (e) {
      error.value = 'That did not save. Please try again.';
      return null;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _authWorker?.dispose();
    _debounce?.cancel();
    super.onClose();
  }
}
