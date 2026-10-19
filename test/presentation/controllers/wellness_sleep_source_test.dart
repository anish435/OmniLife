import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/entities/wellness_log.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/repositories/wellness_repository.dart';
import 'package:omnilife/domain/services/sleep_source.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_sleep_source.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/wellness_controller.dart';

import 'task_controller_test.dart' show FakeAuthRepository;

class _Events implements LifeEventRepository {
  _Events(this.events);
  final List<LifeEvent> events;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  }) => throw UnimplementedError();
  @override
  Future<LifeEvent> update(LifeEvent event) => throw UnimplementedError();
  @override
  Future<void> delete(LifeEvent event) => throw UnimplementedError();
  @override
  Future<List<LifeEvent>> range(String uid, DateTime from, DateTime to) async =>
      events
          .where(
            (e) =>
                e.uid == uid &&
                !e.timestamp.isBefore(from) &&
                e.timestamp.isBefore(to),
          )
          .toList();
  @override
  Future<void> refreshFromRemote(String uid, {int days = 90}) async {}
}

LifeEvent _ev(String id, LifeEventType type, DateTime at) => LifeEvent(
  id: id,
  uid: 'u1',
  type: type,
  timestamp: at,
  createdAt: at,
  updatedAt: at,
);

class _Repo implements WellnessRepository {
  WellnessLog? stored;
  @override
  Future<void> saveLog(String userId, WellnessLog log) async => stored = log;
  @override
  Future<WellnessLog?> getLogForDate(String userId, DateTime date) async =>
      stored;
  @override
  Future<List<WellnessLog>> getLogsForMonth(
    String userId,
    int year,
    int month,
  ) async => const [];
  @override
  Future<void> syncUnsyncedLogs(String userId) async {}
}

class _FixedSource implements SleepSource {
  _FixedSource(this.hours);
  final double? hours;
  @override
  Future<double?> sleepHoursFor(String uid, DateTime day) async => hours;
}

void main() {
  group('PulseSleepSource', () {
    final day = DateTime(2026, 3, 10);

    test('uses the night that ended on that day', () async {
      final source = PulseSleepSource(
        _Events([
          _ev('s', LifeEventType.sleepStart, DateTime(2026, 3, 9, 23)),
          _ev('w', LifeEventType.wake, DateTime(2026, 3, 10, 6, 30)),
        ]),
      );
      expect(await source.sleepHoursFor('u1', day), 7.5);
    });

    test(
      'is null when nothing was recorded or the night is another day',
      () async {
        final source = PulseSleepSource(
          _Events([
            _ev('s', LifeEventType.sleepStart, DateTime(2026, 3, 8, 23)),
            _ev('w', LifeEventType.wake, DateTime(2026, 3, 9, 7)),
          ]),
        );
        expect(await source.sleepHoursFor('u1', day), isNull);
        expect(
          await PulseSleepSource(_Events([])).sleepHoursFor('u1', day),
          isNull,
        );
      },
    );
  });

  group('WellnessController sleep default', () {
    late _Repo repo;

    Future<WellnessController> build(SleepSource? source) async {
      Get.testMode = true;
      Get.reset();
      repo = _Repo();
      final auth = AuthController(
        authRepository: FakeAuthRepository(const AppUser(uid: 'u1')),
      )..currentUser.value = const AppUser(uid: 'u1');
      Get.put<AuthController>(auth);
      Get.put<WellnessRepository>(repo);
      final c = WellnessController(sleepSource: source);
      c.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return c;
    }

    tearDown(Get.reset);

    test(
      'fills sleep hours from Pulse when there is no manual entry',
      () async {
        final c = await build(_FixedSource(7.5));
        expect(c.currentLog.value!.sleepDurationHours, 7.5);
        expect(c.sleepFromPulse.value, isTrue);
      },
    );

    test('a manual entry is never overwritten', () async {
      final day = DateTime.now();
      repo = _Repo()
        ..stored = WellnessLog(
          id: 'u1_x',
          date: DateTime(day.year, day.month, day.day),
          sleepDurationHours: 6,
        );
      Get.testMode = true;
      Get.reset();
      Get.put<AuthController>(
        AuthController(
          authRepository: FakeAuthRepository(const AppUser(uid: 'u1')),
        )..currentUser.value = const AppUser(uid: 'u1'),
      );
      Get.put<WellnessRepository>(repo);
      final c = WellnessController(sleepSource: _FixedSource(8));
      c.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.currentLog.value!.sleepDurationHours, 6);
      expect(c.sleepFromPulse.value, isFalse);
    });

    test('moving the slider clears the Pulse note', () async {
      final c = await build(_FixedSource(7));
      c.updateSleepDuration(8);
      expect(c.sleepFromPulse.value, isFalse);
      expect(c.currentLog.value!.sleepDurationHours, 8);
    });

    test('without a source or data the log stays empty', () async {
      var c = await build(null);
      expect(c.currentLog.value!.sleepDurationHours, 0);
      c = await build(_FixedSource(null));
      expect(c.currentLog.value!.sleepDurationHours, 0);
      expect(c.sleepFromPulse.value, isFalse);
    });
  });
}
