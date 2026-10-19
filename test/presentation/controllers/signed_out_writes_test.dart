import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/errors/user_messages.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/pulse_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';

import 'task_controller_test.dart' show FakeAuthRepository, FakeTaskRepository;

class _NoopEvents implements LifeEventRepository {
  var recorded = 0;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  }) async {
    recorded++;
    final now = DateTime.now();
    return LifeEvent(
      id: 'e',
      uid: uid,
      type: type,
      timestamp: now,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
  }

  @override
  Future<LifeEvent> update(LifeEvent event) async => event;
  @override
  Future<void> delete(LifeEvent event) async {}
  @override
  Future<List<LifeEvent>> range(String uid, DateTime from, DateTime to) async =>
      const [];
  @override
  Future<void> refreshFromRemote(String uid, {int days = 90}) async {}
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  test('pulse quick-log while signed out says to sign in', () async {
    final events = _NoopEvents();
    final controller = PulseController(
      service: PulseService(events: events),
      events: events,
      uidProvider: () => null,
    );
    final result = await controller.log(LifeEventType.water);
    expect(result, isNull);
    expect(controller.error.value, signInToSaveMessage);
    expect(signInToSaveMessage, 'Sign in to save this.');
    expect(events.recorded, 0);
  });

  test('creating a task while signed out says to sign in', () async {
    final auth = AuthController(authRepository: FakeAuthRepository());
    auth.onInit();
    final repo = FakeTaskRepository();
    final controller = TaskController(
      taskRepository: repo,
      authController: auth,
    );
    final created = await controller.createTask(title: 'Water the plants');
    expect(created, isNull);
    expect(controller.errorMessage.value, signInToSaveMessage);
    expect(repo.storage, isEmpty);
  });
}
