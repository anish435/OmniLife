import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/core/sync/sync_engine.dart';
import 'package:omnilife/domain/entities/life_event.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/domain/repositories/calendar_repository.dart';
import 'package:omnilife/domain/repositories/life_event_repository.dart';
import 'package:omnilife/domain/repositories/task_repository.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_insights_service.dart';
import 'package:omnilife/domain/usecases/pulse/pulse_service.dart';
import 'package:omnilife/presentation/controllers/app_controller.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/controllers/calendar_controller.dart';
import 'package:omnilife/presentation/controllers/pulse_controller.dart';
import 'package:omnilife/presentation/controllers/sync_controller.dart';
import 'package:omnilife/presentation/controllers/task_controller.dart';
import 'package:omnilife/presentation/pages/dashboard/dashboard_page.dart';

import '../../support/fake_habit_repositories.dart';
import '../controllers/calendar_controller_test.dart' show FakeCalendarRepository;
import '../controllers/task_controller_test.dart' show FakeAuthRepository, FakeTaskRepository;

class _TestLifeEventRepo implements LifeEventRepository {
  final events = <String, LifeEvent>{};

  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<LifeEvent> record(String uid, LifeEventType type, {DateTime? at, Map<String, dynamic> metadata = const {}}) async {
    final now = DateTime.now();
    final e = LifeEvent(id: 'e1', uid: uid, type: type, timestamp: at ?? now, createdAt: now, updatedAt: now, metadata: metadata);
    events[e.id] = e;
    return e;
  }
  @override
  Future<LifeEvent> update(LifeEvent event) async => event;
  @override
  Future<void> delete(LifeEvent event) async => events.remove(event.id);
  @override
  Future<List<LifeEvent>> range(String uid, DateTime from, DateTime to) async => events.values.toList();
  @override
  Future<void> refreshFromRemote(String uid, {int days = 90}) async {}
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
  const user = AppUser(uid: 'u1', email: 'test@example.com', displayName: 'Jane Doe');

  setUp(() {
    Get.testMode = true;
    Get.reset();

    final appController = AppController();
    Get.put<AppController>(appController);

    final authRepo = FakeAuthRepository(user);
    final authController = AuthController(authRepository: authRepo);
    authController.onInit();
    Get.put<AuthRepository>(authRepo);
    Get.put<AuthController>(authController);

    final taskRepo = FakeTaskRepository();
    final taskController = TaskController(taskRepository: taskRepo, authController: authController);
    taskController.onInit();
    Get.put<TaskRepository>(taskRepo);
    Get.put<TaskController>(taskController);

    final calRepo = FakeCalendarRepository();
    final calController = CalendarController(calendarRepository: calRepo, authController: authController);
    calController.onInit();
    Get.put<CalendarRepository>(calRepo);
    Get.put<CalendarController>(calController);

    final syncController = FakeSyncController();
    Get.put<SyncController>(syncController);

    final lifeRepo = _TestLifeEventRepo();
    final pulseService = PulseService(events: lifeRepo);
    final insightsService = PulseInsightsService(
      events: lifeRepo,
      tasks: taskRepo,
      habits: FakeHabitRepository(),
    );
    final pulseController = PulseController(
      service: pulseService,
      insights: insightsService,
      events: lifeRepo,
      uidProvider: () => 'u1',
    );
    Get.put<PulseController>(pulseController);
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpDashboard(WidgetTester tester, {double width = 375, double height = 812}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const DashboardPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DashboardPage responsive phone rendering', () {
    testWidgets('renders cleanly at 375px phone width without any overflow', (tester) async {
      await pumpDashboard(tester, width: 375);

      expect(find.textContaining('Good'), findsOneWidget);
      expect(find.text('LOG A MOMENT'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('MODULES'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('MODULES'), findsOneWidget);

      expect(find.text('Tasks'), findsWidgets);
      expect(find.text('Calendar'), findsWidgets);
      expect(find.text('Pulse'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly at 390px width without overflow', (tester) async {
      await pumpDashboard(tester, width: 390);
      await tester.scrollUntilVisible(
        find.text('MODULES'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('MODULES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly at 430px width without overflow', (tester) async {
      await pumpDashboard(tester, width: 430);
      await tester.scrollUntilVisible(
        find.text('MODULES'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('MODULES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pulse quick-log strip displays on dashboard and allows one-tap water log', (tester) async {
      await pumpDashboard(tester, width: 375);

      final waterBtn = find.widgetWithText(OutlinedButton, 'Water');
      await tester.scrollUntilVisible(
        waterBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(waterBtn, findsOneWidget);

      await tester.tap(waterBtn);
      await tester.pumpAndSettle();

      expect(find.text('Water logged · 250 ml'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
