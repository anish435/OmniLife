import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/app/routes/app_routes.dart';
import 'package:omnilife/core/services/notification_routing.dart';
import 'package:omnilife/core/services/notification_service.dart';

void main() {
  group('NotificationRouting.fromPayload', () {
    test('maps kind:id payloads to named routes', () {
      expect(
        NotificationRouting.fromPayload('task:abc'),
        const NotificationTarget(
          AppRoutes.tasks,
          id: 'abc',
          kind: NotificationRouting.kindTask,
        ),
      );
      expect(
        NotificationRouting.fromPayload('habit:h1')?.route,
        AppRoutes.habits,
      );
      expect(
        NotificationRouting.fromPayload('calendar:e1')?.route,
        AppRoutes.calendar,
      );
      expect(NotificationRouting.fromPayload('focus')?.route, AppRoutes.focus);
      expect(
        NotificationRouting.fromPayload('note:n1')?.route,
        AppRoutes.notes,
      );
    });

    test('keeps ids that contain colons intact', () {
      expect(NotificationRouting.fromPayload('task:a:b')?.id, 'a:b');
    });

    test('understands legacy bare ids', () {
      expect(
        NotificationRouting.fromPayload('task_123_4')?.route,
        AppRoutes.tasks,
      );
      expect(
        NotificationRouting.fromPayload('event_99_1')?.route,
        AppRoutes.calendar,
      );
      expect(
        NotificationRouting.fromPayload('demo_event_1')?.route,
        AppRoutes.calendar,
      );
    });

    test('returns null for empty, unknown or dangerous payloads', () {
      expect(NotificationRouting.fromPayload(null), isNull);
      expect(NotificationRouting.fromPayload('  '), isNull);
      expect(NotificationRouting.fromPayload('whatever'), isNull);
      expect(NotificationRouting.fromPayload('login:1'), isNull);
      expect(NotificationRouting.fromPayload('/login'), isNull);
    });

    test('encode round trips', () {
      final payload = NotificationRouting.encode('task', 't9');
      expect(payload, 'task:t9');
      expect(NotificationRouting.fromPayload(payload)?.id, 't9');
      expect(NotificationRouting.encode('focus'), 'focus');
    });
  });

  group('NotificationRouting.fromData (FCM)', () {
    test('uses route or type plus id', () {
      expect(
        NotificationRouting.fromData({'route': 'task', 'id': '7'}),
        const NotificationTarget(AppRoutes.tasks, id: '7', kind: 'task'),
      );
      expect(
        NotificationRouting.fromData({'type': 'habit'})?.route,
        AppRoutes.habits,
      );
      expect(
        NotificationRouting.fromData({'route': '/calendar'})?.route,
        AppRoutes.calendar,
      );
      expect(
        NotificationRouting.fromData({'route': '/focus'})?.route,
        AppRoutes.focus,
      );
    });

    test('falls back to a payload entry', () {
      expect(NotificationRouting.fromData({'payload': 'task:5'})?.id, '5');
    });

    test('rejects routes that are not allow-listed', () {
      expect(NotificationRouting.fromData({'route': '/login'}), isNull);
      expect(NotificationRouting.fromData({'route': 'dashboard'}), isNull);
      expect(NotificationRouting.fromData({}), isNull);
      expect(NotificationRouting.fromData(null), isNull);
    });
  });

  group('NotificationService.normalizePayload', () {
    test('rewrites legacy ids to kind:id', () {
      expect(NotificationService.normalizePayload('task_1'), 'task:task_1');
      expect(
        NotificationService.normalizePayload('event_2'),
        'calendar:event_2',
      );
      expect(NotificationService.normalizePayload('task:3'), 'task:3');
      expect(NotificationService.normalizePayload(null), isNull);
    });
  });

  group('NotificationNavigator', () {
    test('navigates immediately when ready', () {
      final opened = <(String, Object?)>[];
      final nav = NotificationNavigator(
        isReady: () => true,
        navigate: (r, a) => opened.add((r, a)),
        currentRoute: () => AppRoutes.dashboard,
      );

      nav.handle(NotificationRouting.fromPayload('task:42'));

      expect(opened, [(AppRoutes.tasks, '42')]);
      expect(nav.pending, isNull);
    });

    test('defers a cold-start tap until the app is ready', () {
      var ready = false;
      final opened = <(String, Object?)>[];
      final nav = NotificationNavigator(
        isReady: () => ready,
        navigate: (r, a) => opened.add((r, a)),
        currentRoute: () => AppRoutes.dashboard,
      );

      nav.handle(NotificationRouting.fromPayload('focus'));
      expect(opened, isEmpty);
      expect(nav.pending?.route, AppRoutes.focus);
      expect(nav.flushPending(), isFalse);

      ready = true;
      expect(nav.flushPending(), isTrue);
      expect(opened, [(AppRoutes.focus, null)]);
      expect(nav.pending, isNull);
    });

    test('does not push the route that is already open', () {
      final opened = <(String, Object?)>[];
      final nav = NotificationNavigator(
        isReady: () => true,
        navigate: (r, a) => opened.add((r, a)),
        currentRoute: () => AppRoutes.tasks,
      );
      nav.handle(NotificationRouting.fromPayload('task:1'));
      expect(opened, isEmpty);
    });

    test('ignores null targets', () {
      final nav = NotificationNavigator(
        isReady: () => true,
        navigate: (r, a) => fail('should not navigate'),
        currentRoute: () => '/',
      );
      nav.handle(null);
      expect(nav.pending, isNull);
    });
  });
}
