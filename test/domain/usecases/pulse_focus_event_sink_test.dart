import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/bindings/pulse_bindings.dart';
import 'package:omnilife/core/sync/sync_engine.dart';
import 'package:omnilife/domain/entities/focus_session.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/focus/focus_event_sink.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_focus_event_sink.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';

import '../../support/sync_fakes.dart';

class _Events implements LifeEventRepository {
  final recorded = <LifeEvent>[];
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  }) async {
    final now = DateTime(2026, 3, 1, 12);
    final e = LifeEvent(
      id: 'e${recorded.length}',
      uid: uid,
      type: type,
      timestamp: at ?? now,
      createdAt: now,
      updatedAt: now,
      metadata: metadata,
    );
    recorded.add(e);
    return e;
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

FocusSession _session({int focused = 1500, String uid = 'u1'}) => FocusSession(
  id: 'focus_1',
  userId: uid,
  startedAt: DateTime(2026, 3, 1, 9),
  endedAt: DateTime(2026, 3, 1, 9, 25),
  plannedSeconds: 1500,
  focusedSeconds: focused,
);

void main() {
  test('a finished session becomes a focus event with minutes', () async {
    final events = _Events();
    final sink = PulseFocusEventSink(() => PulseService(events: events));

    await sink.onFocusCompleted(_session());

    final e = events.recorded.single;
    expect(e.type, LifeEventType.focus);
    expect(e.uid, 'u1');
    expect(e.metadata['minutes'], 25);
    expect(e.metadata['plannedMinutes'], 25);
    expect(e.timestamp, DateTime(2026, 3, 1, 9, 25));
  });

  test('a session without a user is ignored', () async {
    final events = _Events();
    final sink = PulseFocusEventSink(() => PulseService(events: events));
    await sink.onFocusCompleted(_session(uid: ''));
    expect(events.recorded, isEmpty);
  });

  test('the Pulse bindings register the sink for the focus controller', () {
    Get.testMode = true;
    Get.reset();
    final sync = TestSync();
    Get.put<SyncEngine>(sync.engine);
    registerSyncAndPulse();
    expect(Get.find<FocusEventSink>(), isA<PulseFocusEventSink>());
    Get.reset();
    sync.dispose();
  });
}
