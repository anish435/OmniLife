import '../entities/wellness_log.dart';

abstract class WellnessRepository {
  Future<void> saveLog(String userId, WellnessLog log);
  Future<WellnessLog?> getLogForDate(String userId, DateTime date);
  Future<List<WellnessLog>> getLogsForMonth(String userId, int year, int month);
  Future<void> syncUnsyncedLogs(String userId);
}
