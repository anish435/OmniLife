import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/routes/app_routes.dart';
import 'package:omnilife/app/routes/auth_guard.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
    AuthGuard.clearPendingRoute();
  });

  group('AuthGuard.redirect', () {
    AuthGuard guardFor(AuthStatus? status) =>
        AuthGuard(statusProvider: () => status);

    test('signed out is sent to login from a protected route', () {
      final r = guardFor(AuthStatus.unauthenticated).redirect(AppRoutes.pulse);
      expect(r?.name, AppRoutes.login);
      expect(AuthGuard.pendingRoute, AppRoutes.pulse);
    });

    test('signed in passes through a protected route', () {
      expect(
        guardFor(AuthStatus.authenticated).redirect(AppRoutes.tasks),
        isNull,
      );
      expect(AuthGuard.pendingRoute, isNull);
    });

    test('while the session is being checked, protected goes to splash', () {
      final r = guardFor(AuthStatus.initializing).redirect('/pulse?x=1');
      expect(r?.name, AppRoutes.splash);
      expect(AuthGuard.takePendingRoute(), '/pulse?x=1');
      expect(AuthGuard.pendingRoute, isNull);
    });

    test('splash is never redirected', () {
      for (final s in AuthStatus.values) {
        expect(guardFor(s).redirect(AppRoutes.splash), isNull);
      }
    });

    test('signed in opening login or register goes to the dashboard', () {
      final g = guardFor(AuthStatus.authenticated);
      expect(g.redirect(AppRoutes.login)?.name, AppRoutes.dashboard);
      expect(g.redirect(AppRoutes.register)?.name, AppRoutes.dashboard);
    });

    test('signed out can open login and register', () {
      final g = guardFor(AuthStatus.unauthenticated);
      expect(g.redirect(AppRoutes.login), isNull);
      expect(g.redirect(AppRoutes.register), isNull);
      expect(
        guardFor(AuthStatus.initializing).redirect(AppRoutes.login),
        isNull,
      );
    });

    test('with no auth controller nothing is blocked', () {
      expect(AuthGuard().redirect(AppRoutes.finance), isNull);
    });
  });

  group('AuthGuard.protect', () {
    final pages = [
      GetPage<dynamic>(name: AppRoutes.splash, page: () => const SizedBox()),
      GetPage<dynamic>(name: AppRoutes.login, page: () => const SizedBox()),
      GetPage<dynamic>(name: AppRoutes.pulse, page: () => const SizedBox()),
    ];

    test('guards everything except splash and keeps bindings', () {
      final guarded = AuthGuard.protect(pages);
      expect(guarded.length, pages.length);
      expect(guarded[0].middlewares, isNull);
      expect(guarded[1].middlewares?.whereType<AuthGuard>(), hasLength(1));
      expect(guarded[2].middlewares?.whereType<AuthGuard>(), hasLength(1));
    });
  });

  group('navigation with a mounted app', () {
    Widget app(AuthStatus Function() status, String initial) {
      return GetMaterialApp(
        initialRoute: initial,
        getPages: AuthGuard.protect([
          GetPage<dynamic>(
            name: AppRoutes.splash,
            page: () => const Text('splash page'),
          ),
          GetPage<dynamic>(
            name: AppRoutes.login,
            page: () => const Text('login page'),
          ),
          GetPage<dynamic>(
            name: AppRoutes.dashboard,
            page: () => const Text('dashboard page'),
          ),
          GetPage<dynamic>(
            name: AppRoutes.pulse,
            page: () => const Text('pulse page'),
          ),
        ], statusProvider: status),
      );
    }

    testWidgets('deep link while signed out lands on login', (tester) async {
      await tester.pumpWidget(app(() => AuthStatus.unauthenticated, '/pulse'));
      await tester.pumpAndSettle();
      expect(find.text('login page'), findsOneWidget);
      expect(find.text('pulse page'), findsNothing);
    });

    testWidgets('deep link while signed in opens the page', (tester) async {
      await tester.pumpWidget(app(() => AuthStatus.authenticated, '/pulse'));
      await tester.pumpAndSettle();
      expect(find.text('pulse page'), findsOneWidget);
    });

    testWidgets('signed in opening login is sent to dashboard', (tester) async {
      await tester.pumpWidget(app(() => AuthStatus.authenticated, '/login'));
      await tester.pumpAndSettle();
      expect(find.text('dashboard page'), findsOneWidget);
    });

    testWidgets('splash still shows while the session loads', (tester) async {
      await tester.pumpWidget(app(() => AuthStatus.initializing, '/splash'));
      await tester.pumpAndSettle();
      expect(find.text('splash page'), findsOneWidget);
    });
  });
}
