import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/entities/wellness_log.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/repositories/wellness_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_water_source.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/wellness_controller.dart';

import 'task_controller_test.dart' show FakeAuthRepository;

class _Events implements LifeEventRepository {
  final events = <String, LifeEvent>{};

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  }) async {
    final t = at ?? DateTime.now();
    final e = LifeEvent(
      id: 'e${events.length + 1}',
      uid: uid,
      type: type,
      timestamp: t,
      createdAt: t,
      updatedAt: t,
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
      events.values
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

void main() {
  late _Events events;
  late PulseWaterSource source;

  setUp(() {
    events = _Events();
    source = PulseWaterSource(events);
  });

  tearDown(Get.reset);

  Future<WellnessController> build() async {
    Get.testMode = true;
    Get.reset();
    Get.put<AuthController>(
      AuthController(
        authRepository: FakeAuthRepository(const AppUser(uid: 'u1')),
      )..currentUser.value = const AppUser(uid: 'u1'),
    );
    Get.put<WellnessRepository>(_Repo());
    final c = WellnessController(waterSource: source);
    c.onInit();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return c;
  }

  test('Pulse total counts events without an ml value as 250', () async {
    final now = DateTime.now();
    await events.record('u1', LifeEventType.water, at: now);
    await events.record(
      'u1',
      LifeEventType.water,
      at: now,
      metadata: {'ml': 500},
    );
    await events.record('u1', LifeEventType.mood, at: now);
    expect(await source.totalMlFor('u1', now), 750);
  });

  test('Wellness shows what Pulse already has for today', () async {
    await events.record(
      'u1',
      LifeEventType.water,
      at: DateTime.now(),
      metadata: {'ml': 500},
    );
    final c = await build();
    expect(c.currentLog.value!.waterIntakeMl, 500);
  });

  test('plus on Wellness logs a Pulse water event', () async {
    final c = await build();
    c.updateWaterIntake(250);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.currentLog.value!.waterIntakeMl, 250);
    expect(await source.totalMlFor('u1', DateTime.now()), 250);
    expect(
      events.events.values.where((e) => e.type == LifeEventType.water),
      hasLength(1),
    );
  });

  test('minus takes water back from Pulse, newest first', () async {
    final now = DateTime.now();
    await events.record(
      'u1',
      LifeEventType.water,
      at: now.subtract(const Duration(minutes: 5)),
      metadata: {'ml': 250},
    );
    await events.record(
      'u1',
      LifeEventType.water,
      at: now,
      metadata: {'ml': 500},
    );
    final c = await build();
    expect(c.currentLog.value!.waterIntakeMl, 750);

    c.updateWaterIntake(-250);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(c.currentLog.value!.waterIntakeMl, 500);
    expect(await source.totalMlFor('u1', now), 500);
  });

  test('minus at zero does nothing', () async {
    final c = await build();
    c.updateWaterIntake(-250);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.currentLog.value!.waterIntakeMl, 0);
    expect(events.events, isEmpty);
  });
}
