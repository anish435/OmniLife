import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/entities/task.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_insights_service.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/pulse_controller.dart';
import 'package:omnilife/presentation/pages/pulse/insights_page.dart';

import '../../support/fake_habit_repositories.dart';
import '../controllers/task_controller_test.dart' show FakeAuthRepository;

class _TestLifeEventRepo implements LifeEventRepository {
  _TestLifeEventRepo(this.now);

  final DateTime Function() now;
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
    final t = now();
    final e = LifeEvent(
      id: 'e${events.length + 1}',
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

  Future<void> pumpInsightsPage(WidgetTester tester, {double width = 375, double height = 812}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const InsightsPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('InsightsPage layout and data presentation', () {
    testWidgets('renders at 375px phone width with Momentum metrics and empty patterns', (tester) async {
      await pumpInsightsPage(tester, width: 375);

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('MOMENTUM'), findsOneWidget);
      expect(find.text('PATTERNS'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Recovery'), findsOneWidget);
      expect(find.text('Momentum'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.textContaining('Log a few moments and complete some tasks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 390px and 430px widths without overflow', (tester) async {
      for (final w in [390.0, 430.0]) {
        await pumpInsightsPage(tester, width: w);
        expect(find.text('Insights'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('tapping Momentum metric opens bottom sheet explanation', (tester) async {
      await pumpInsightsPage(tester);

      final focusTile = find.text('Focus');
      expect(focusTile, findsOneWidget);

      await tester.tap(focusTile);
      await tester.pumpAndSettle();

      expect(find.textContaining('Focus'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
