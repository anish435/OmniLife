import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/push_messaging_service.dart';
import 'package:omnilife/core/services/push_registration_manager.dart';

import '../../support/focus_push_fakes.dart';

void main() {
  late FakePushMessaging messaging;
  late FakeDeviceTokenStore store;
  late InMemoryPushPreferences prefs;
  late PushRegistrationManager manager;
  final fixedNow = DateTime.utc(2026, 10, 6, 8);

  PushRegistrationManager build({
    void Function(PushMessage)? onForeground,
    void Function(PushMessage)? onOpened,
  }) => PushRegistrationManager(
    messaging: messaging,
    store: store,
    preferences: prefs,
    onForeground: onForeground,
    onOpened: onOpened,
    clock: () => fixedNow,
  );

  setUp(() {
    messaging = FakePushMessaging();
    store = FakeDeviceTokenStore();
    prefs = InMemoryPushPreferences();
    manager = build();
  });

  tearDown(() => manager.dispose());

  String docFor(String token) => PushRegistrationManager.docIdForToken(token);

  test('signing in never prompts for permission or registers', () async {
    await manager.onSignedIn('u1');
    expect(messaging.permissionRequests, 0);
    expect(store.forUser('u1'), isEmpty);
  });

  test(
    'enable asks permission, then stores token, platform, updatedAt',
    () async {
      final result = await manager.enable('u1');

      expect(result, PushPermission.granted);
      expect(messaging.permissionRequests, 1);
      final doc = store.forUser('u1')[docFor('token-1')]!;
      expect(doc['token'], 'token-1');
      expect(doc['platform'], 'android');
      expect(doc['updatedAt'], fixedNow);
      expect(await manager.isEnabled(), isTrue);
    },
  );

  test('document id is a hash, not the raw token', () {
    final id = docFor('secret-token');
    expect(id, isNot(contains('secret')));
    expect(id.length, 64);
    expect(docFor('secret-token'), id);
    expect(docFor('other'), isNot(id));
  });

  test('after opting in, a later login registers silently', () async {
    await manager.enable('u1');
    await manager.onBeforeSignOut('u1');
    expect(store.forUser('u1'), isEmpty);

    messaging.token = 'token-2';
    messaging.permissionRequests = 0;
    await manager.onSignedIn('u1');

    expect(messaging.permissionRequests, 0);
    expect(store.forUser('u1').keys, [docFor('token-2')]);
  });

  test('token refresh replaces the old registration', () async {
    await manager.enable('u1');
    messaging.refresh.add('token-rotated');
    await Future<void>.delayed(Duration.zero);

    expect(store.forUser('u1').keys, [docFor('token-rotated')]);
    expect(manager.currentToken, 'token-rotated');
  });

  test(
    'sign out removes this device and its token, and stops refresh',
    () async {
      await manager.enable('u1');
      await manager.setTopic(PushTopics.tips, subscribed: true);

      await manager.onBeforeSignOut('u1');

      expect(store.forUser('u1'), isEmpty);
      expect(messaging.tokenDeletions, 1);
      expect(messaging.subscribed, isEmpty);

      messaging.refresh.add('late-token');
      await Future<void>.delayed(Duration.zero);
      expect(store.forUser('u1'), isEmpty);
    },
  );

  test('registrations are scoped per user', () async {
    await manager.enable('u1');
    await manager.onBeforeSignOut('u1');
    messaging.token = 'token-b';
    await manager.enable('u2');

    expect(store.forUser('u1'), isEmpty);
    expect(store.forUser('u2').keys, [docFor('token-b')]);
  });

  test(
    'disable removes the token document and turns the preference off',
    () async {
      await manager.enable('u1');
      await manager.disable('u1');

      expect(store.forUser('u1'), isEmpty);
      expect(await prefs.getEnabled(), isFalse);
      expect(await manager.isEnabled(), isFalse);
    },
  );

  group('permission handling', () {
    test('denied once on Android can be retried', () async {
      messaging.requestResult = PushPermission.denied;
      expect(await manager.enable('u1'), PushPermission.denied);
      expect(store.forUser('u1'), isEmpty);
      expect(await prefs.getEnabled(), isFalse);
    });

    test('second Android denial becomes permanently denied', () async {
      messaging.requestResult = PushPermission.denied;
      await manager.enable('u1');
      expect(await manager.enable('u1'), PushPermission.permanentlyDenied);
    });

    test('one iOS denial is already permanent', () async {
      messaging.platformName = 'ios';
      messaging.requestResult = PushPermission.denied;
      expect(await manager.enable('u1'), PushPermission.permanentlyDenied);
    });

    test('an OS-reported permanent denial is passed through', () async {
      messaging.requestResult = PushPermission.permanentlyDenied;
      expect(await manager.enable('u1'), PushPermission.permanentlyDenied);
      expect(store.forUser('u1'), isEmpty);
    });

    test('already granted permission is not requested again', () async {
      messaging.permission = PushPermission.granted;
      await manager.enable('u1');
      expect(messaging.permissionRequests, 0);
      expect(store.forUser('u1'), isNotEmpty);
    });

    test('a successful grant resets the denial counter', () async {
      messaging.requestResult = PushPermission.denied;
      await manager.enable('u1');
      messaging.requestResult = PushPermission.granted;
      await manager.enable('u1');
      expect(await prefs.getDeniedCount(), 0);
    });
  });

  group('unsupported platforms', () {
    test('everything is a quiet no-op', () async {
      messaging.supported = false;
      expect(await manager.enable('u1'), PushPermission.notDetermined);
      await manager.onSignedIn('u1');
      await manager.onBeforeSignOut('u1');
      await manager.start();
      expect(messaging.permissionRequests, 0);
      expect(store.docs, isEmpty);
    });

    test('UnsupportedPushMessagingService never throws', () async {
      const service = UnsupportedPushMessagingService();
      expect(await service.isSupported, isFalse);
      expect(await service.getToken(), isNull);
      expect(await service.getInitialMessage(), isNull);
      await service.subscribeToTopic('tips');
      await service.deleteToken();
    });
  });

  group('topics', () {
    test(
      'subscribe and unsubscribe update the service and preferences',
      () async {
        await manager.setTopic(PushTopics.announcements, subscribed: true);
        expect(messaging.subscribed, {PushTopics.announcements});
        expect(await manager.subscribedTopics(), {PushTopics.announcements});

        await manager.setTopic(PushTopics.announcements, subscribed: false);
        expect(messaging.subscribed, isEmpty);
        expect(await manager.subscribedTopics(), isEmpty);
      },
    );

    test(
      'saved topics are re-subscribed when notifications are enabled',
      () async {
        prefs.topics = {PushTopics.tips};
        await manager.enable('u1');
        expect(messaging.subscribed, {PushTopics.tips});
      },
    );
  });

  group('message streams', () {
    test('foreground, opened and initial messages are delivered', () async {
      final foreground = <PushMessage>[];
      final opened = <PushMessage>[];
      messaging.initial = const PushMessage(data: {'route': 'focus'});
      final m = build(onForeground: foreground.add, onOpened: opened.add);

      await m.start();
      messaging.foreground.add(const PushMessage(title: 'Hi'));
      messaging.opened.add(const PushMessage(data: {'route': 'task'}));
      await Future<void>.delayed(Duration.zero);

      expect(foreground.single.title, 'Hi');
      expect(opened.map((e) => e.data['route']), ['focus', 'task']);
      await m.dispose();
    });
  });
}
