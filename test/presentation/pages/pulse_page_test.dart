import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/core/sync/sync_engine.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_insights_service.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/pulse_controller.dart';
import 'package:omnilife/presentation/controllers/sync_controller.dart';
import 'package:omnilife/presentation/pages/pulse/pulse_page.dart';

import '../../support/fake_habit_repositories.dart';
import '../controllers/task_controller_test.dart' show FakeAuthRepository;

class _TestLifeEventRepo implements LifeEventRepository {
  _TestLifeEventRepo(this.now);

  final DateTime Function() now;
  final events = <String, LifeEvent>{};
  var _seq = 0;

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
      id: 'e${++_seq}',
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
  Future<LifeEvent> update(LifeEvent event) async {
    events[event.id] = event;
    return event;
  }

  @override
  Future<void> delete(LifeEvent event) async {
    events.remove(event.id);
  }

  @override
  Future<List<LifeEvent>> range(String uid, DateTime from, DateTime to) async {
    return events.values
        .where(
          (e) =>
              e.uid == uid &&
              !e.timestamp.isBefore(from) &&
              e.timestamp.isBefore(to),
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> refreshFromRemote(String uid, {int days = 90}) async {}
}

class _EmptyTaskRepo implements TaskRepository {
  @override
  Future<List<Task>> getTasks(String userId) async => const [];
  @override
  Future<Task?> getTask(String id) async => null;
  @override
  Future<Task> createTask(Task task) async => task;
  @override
  Future<Task> updateTask(Task task) async => task;
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<Task> completeTask(String id) async => throw UnimplementedError();
}

class FakeSyncController extends GetxController implements SyncController {
  FakeSyncController([SyncStatus status = SyncStatus.synced, int pending = 0])
      : snapshot = Rx<SyncSnapshot>(SyncSnapshot(status: status, pendingCount: pending));

  @override
  final Rx<SyncSnapshot> snapshot;

  @override
  SyncEngine get engine => throw UnimplementedError();

  @override
  Future<void> retry() async {}
}

void main() {
  const testUser = AppUser(uid: 'u1', email: 'user@example.com');
  late DateTime clock;
  late _TestLifeEventRepo lifeEventRepo;
  late PulseService pulseService;
  late PulseInsightsService insightsService;
  late PulseController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clock = DateTime(2026, 3, 2, 10, 0);
    lifeEventRepo = _TestLifeEventRepo(() => clock);
    pulseService = PulseService(events: lifeEventRepo, now: () => clock);
    insightsService = PulseInsightsService(
      events: lifeEventRepo,
      tasks: _EmptyTaskRepo(),
      habits: FakeHabitRepository(),
      now: () => clock,
    );

    final authRepo = FakeAuthRepository(testUser);
    final authController = AuthController(authRepository: authRepo);
    authController.onInit();
    Get.put<AuthRepository>(authRepo);
    Get.put<AuthController>(authController);

    final syncController = FakeSyncController();
    Get.put<SyncController>(syncController);

    controller = PulseController(
      service: pulseService,
      insights: insightsService,
      events: lifeEventRepo,
      uidProvider: () => 'u1',
      now: () => clock,
    );
    Get.put<PulseController>(controller);
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpPulsePage(WidgetTester tester, {double width = 375, double height = 812}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const PulsePage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PulsePage reactive ownership and layout', () {
    testWidgets('renders at 375px phone width without errors or overflow', (tester) async {
      await pumpPulsePage(tester, width: 375);

      expect(find.text('Pulse'), findsOneWidget);
      expect(find.text('LOG A MOMENT'), findsOneWidget);
      expect(find.text('YOUR DAY'), findsOneWidget);
      expect(find.text('TIMELINE'), findsOneWidget);
      expect(find.text('Nothing logged yet. Tap a button above to record a moment.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 390px and 430px widths without overflow', (tester) async {
      for (final w in [390.0, 430.0]) {
        await pumpPulsePage(tester, width: w);
        expect(find.text('Pulse'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('tapping Water immediately logs and shows Undo snackbar', (tester) async {
      await pumpPulsePage(tester);

      final waterBtn = find.widgetWithText(OutlinedButton, 'Water');
      expect(waterBtn, findsOneWidget);

      await tester.tap(waterBtn);
      await tester.pumpAndSettle();

      expect(lifeEventRepo.events.length, 1);
      final loggedEvent = lifeEventRepo.events.values.first;
      expect(loggedEvent.type, LifeEventType.water);

      expect(find.text('Water logged · 250 ml'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Undo removes the logged event', (tester) async {
      await pumpPulsePage(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Water'));
      await tester.pumpAndSettle();

      expect(lifeEventRepo.events.length, 1);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(lifeEventRepo.events.length, 0);
      expect(find.text('Nothing logged yet. Tap a button above to record a moment.'), findsOneWidget);
    });

    testWidgets('Sleep and Wake sequence records duration and updates button to Wake', (tester) async {
      await pumpPulsePage(tester);

      // Tap Sleep
      expect(find.widgetWithText(OutlinedButton, 'Sleep'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sleep'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sleep logged'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Wake'), findsOneWidget);

      // Advance clock 7h 30m
      clock = clock.add(const Duration(hours: 7, minutes: 30));

      // Tap Wake
      await tester.tap(find.widgetWithText(OutlinedButton, 'Wake'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Wake logged · Slept 7h 30m'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Sleep'), findsOneWidget);
    });

    testWidgets('DayNavigator navigates previous day and back to today', (tester) async {
      await pumpPulsePage(tester);

      expect(find.textContaining('Today'), findsOneWidget);

      // Tap previous day
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Today'), findsNothing);

      // Tap next day to return to today
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Today'), findsOneWidget);
    });
  });
}
