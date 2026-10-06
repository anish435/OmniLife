import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';

class _MemoryRepo implements LifeEventRepository {
  _MemoryRepo(this.now);

  final DateTime Function() now;
  final events = <String, LifeEvent>{};
  var _n = 0;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<LifeEvent> record(
    String uid,
    LifeEventType type, {
    DateTime? at,
    Map<String, dynamic> metadata = const {},
  }) async {
    final t = now();
    final e = LifeEvent(
      id: 'e${++_n}',
      uid: uid,
      type: type,
      timestamp: at ?? t,
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
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  @override
  Future<void> refreshFromRemote(String uid, {int days = 90}) async {}
}

void main() {
  late DateTime clock;
  late _MemoryRepo repo;
  late PulseService service;

  setUp(() {
    clock = DateTime(2026, 3, 1, 23, 42);
    repo = _MemoryRepo(() => clock);
    service = PulseService(events: repo, now: () => clock);
  });

  test('one tap on Sleep records bedtime immediately with no form', () async {
    final r = await service.startSleep('u1');

    expect(r.event.type, LifeEventType.sleepStart);
    expect(r.event.timestamp, DateTime(2026, 3, 1, 23, 42));
    expect(r.event.metadata, isEmpty);
    expect(r.alreadyAsleep, isFalse);
  });

  test('tapping Sleep again while asleep does not duplicate', () async {
    final first = await service.startSleep('u1');
    clock = clock.add(const Duration(minutes: 3));

    final again = await service.startSleep('u1');

    expect(again.alreadyAsleep, isTrue);
    expect(again.event.id, first.event.id);
    expect(repo.events, hasLength(1));
  });

  test('Wake closes the open sleep and calculates the duration', () async {
    await service.startSleep('u1');
    clock = DateTime(2026, 3, 2, 7, 18);

    final r = await service.wake('u1');

    expect(r.sleepDuration, const Duration(hours: 7, minutes: 36));
    expect(r.event.type, LifeEventType.wake);
    expect(r.event.metadata['durationMinutes'], 456);
    expect(await service.openSleep('u1'), isNull);
  });

  test(
    'Wake without a Sleep still records, with no invented duration',
    () async {
      clock = DateTime(2026, 3, 2, 7, 18);

      final r = await service.wake('u1');

      expect(r.sleepDuration, isNull);
      expect(r.event.metadata.containsKey('durationMinutes'), isFalse);
    },
  );

  test('water and meals get helpful defaults the user can edit', () async {
    final water = await service.log('u1', LifeEventType.water);
    expect(water.event.metadata['ml'], 250);

    clock = DateTime(2026, 3, 2, 8, 5);
    final breakfast = await service.log('u1', LifeEventType.meal);
    expect(breakfast.event.metadata['kind'], 'breakfast');

    clock = DateTime(2026, 3, 2, 13);
    expect(
      (await service.log('u1', LifeEventType.meal)).event.metadata['kind'],
      'lunch',
    );
  });

  test('undo removes the event; addDetail and correctTime edit it', () async {
    final r = await service.log(
      'u1',
      LifeEventType.mood,
      metadata: {'score': 3},
    );

    final detailed = await service.addDetail(r.event, {'label': 'calm'});
    expect(detailed.metadata, {'score': 3, 'label': 'calm'});

    final fixed = await service.correctTime(detailed, DateTime(2026, 3, 1, 22));
    expect(fixed.timestamp, DateTime(2026, 3, 1, 22));

    await service.undo(fixed);
    expect(repo.events, isEmpty);
  });
}
