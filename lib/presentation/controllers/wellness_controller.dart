// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:get/get.dart';
import '../../domain/entities/wellness_log.dart';
import '../../domain/repositories/wellness_repository.dart';
import '../../domain/services/sleep_source.dart';
import 'auth_controller.dart';

class WellnessController extends GetxController {
  WellnessController({SleepSource? sleepSource}) : _sleepSource = sleepSource;

  final _repository = Get.find<WellnessRepository>();
  final _authController = Get.find<AuthController>();
  final SleepSource? _sleepSource;

  SleepSource? get _sleep =>
      _sleepSource ??
      (Get.isRegistered<SleepSource>() ? Get.find<SleepSource>() : null);

  // State
  final currentLog = Rx<WellnessLog?>(null);

  /// True while the sleep hours shown came from the Pulse sleep log rather
  /// than being typed in. Editing the duration clears it.
  final sleepFromPulse = false.obs;
  final logsForMonth = <WellnessLog>[].obs;
  
  final selectedDate = DateTime.now().obs;
  final isLoading = true.obs;

  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    _loadDataForDate(selectedDate.value);
    
    // Sync unsynced logs
    if (_authController.currentUser.value != null) {
      _repository.syncUnsyncedLogs(_authController.currentUser.value!.uid);
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;
    _loadDataForDate(date);
  }

  Future<void> _loadDataForDate(DateTime date) async {
    isLoading.value = true;
    final userId = _authController.currentUser.value?.uid;
    if (userId == null) {
      isLoading.value = false;
      return;
    }

    try {
      final log = await _repository.getLogForDate(userId, date);
      if (log != null) {
        currentLog.value = log;
      } else {
        // Create an empty log for today
        currentLog.value = WellnessLog(
          id: "",
          date: DateTime(date.year, date.month, date.day),
        );
      }
      await _fillSleepFromPulse(userId, date);

      final monthLogs = await _repository.getLogsForMonth(userId, date.year, date.month);
      logsForMonth.assignAll(monthLogs);
      
    } finally {
      isLoading.value = false;
    }
  }

  /// With no manual sleep entry for the day, default the duration to the
  /// Sleep and Wake taps recorded in Pulse. A typed value always wins.
  Future<void> _fillSleepFromPulse(String userId, DateTime date) async {
    sleepFromPulse.value = false;
    final log = currentLog.value;
    final source = _sleep;
    if (log == null || source == null || log.sleepDurationHours > 0) return;
    try {
      final hours = await source.sleepHoursFor(userId, date);
      // The day may have changed, or the person typed a value, meanwhile.
      if (hours == null ||
          hours <= 0 ||
          currentLog.value != log ||
          log.sleepDurationHours > 0) {
        return;
      }
      currentLog.value = log.copyWith(sleepDurationHours: hours.clamp(0.0, 14.0).toDouble());
      sleepFromPulse.value = true;
    } catch (_) {
      // Pulse unavailable: the manual slider keeps working.
    }
  }

  void updateWaterIntake(int ml) {
    if (currentLog.value == null) return;
    final newValue = (currentLog.value!.waterIntakeMl + ml).clamp(0, 10000);
    currentLog.value = currentLog.value!.copyWith(waterIntakeMl: newValue);
    _debouncedSave();
  }

  void updateSleepDuration(double hours) {
    if (currentLog.value == null) return;
    sleepFromPulse.value = false;
    currentLog.value = currentLog.value!.copyWith(sleepDurationHours: hours);
    _debouncedSave();
  }

  void updateSleepQuality(int quality) {
    if (currentLog.value == null) return;
    currentLog.value = currentLog.value!.copyWith(sleepQuality: quality);
    _debouncedSave();
  }

  void updateWorkoutDuration(int minutes) {
    if (currentLog.value == null) return;
    currentLog.value = currentLog.value!.copyWith(workoutDurationMinutes: minutes);
    _debouncedSave();
  }

  void updateWorkoutType(String type) {
    if (currentLog.value == null) return;
    currentLog.value = currentLog.value!.copyWith(workoutType: type);
    _debouncedSave();
  }

  void updateMoodScore(int score) {
    if (currentLog.value == null) return;
    currentLog.value = currentLog.value!.copyWith(moodScore: score);
    _debouncedSave();
  }

  void _debouncedSave() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _saveLog();
    });
  }

  Future<void> _saveLog() async {
    final userId = _authController.currentUser.value?.uid;
    if (userId == null || currentLog.value == null) return;

    try {
      await _repository.saveLog(userId, currentLog.value!);
      
      // Update logsForMonth optimistically
      final index = logsForMonth.indexWhere((l) => l.date.year == currentLog.value!.date.year && 
                                                   l.date.month == currentLog.value!.date.month &&
                                                   l.date.day == currentLog.value!.date.day);
      if (index != -1) {
        logsForMonth[index] = currentLog.value!;
      } else {
        logsForMonth.add(currentLog.value!);
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to save wellness log: \$e");
    }
  }
}
