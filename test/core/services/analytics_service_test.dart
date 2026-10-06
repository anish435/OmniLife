import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/analytics_service.dart';
import 'package:omnilife/core/services/crash_reporter.dart';

void main() {
  group('AnalyticsSanitizer', () {
    test('keeps numbers, booleans (as 0/1) and short safe strings', () {
      final out = AnalyticsSanitizer.sanitize({
        'method': 'google',
        'planned_minutes': 25,
        'ratio': 0.5,
        'was_paused': true,
      });
      expect(out, {
        'method': 'google',
        'planned_minutes': 25,
        'ratio': 0.5,
        'was_paused': 1,
      });
    });

    test('drops PII-shaped keys regardless of value', () {
      final out = AnalyticsSanitizer.sanitize({
        'email': 'a@b.com',
        'user_email': 'a@b.com',
        'title': 'Pay rent',
        'task_title': 'Pay rent',
        'amount': 120.5,
        'note': 'private',
        'display_name': 'Sam',
        'phone': '555',
        'uid': 'abc',
        'method': 'email',
      });
      expect(out, {'method': 'email'});
    });

    test('drops free text and email-like string values', () {
      final out = AnalyticsSanitizer.sanitize({
        'source': 'someone@example.com',
        'reason': 'this has spaces in it',
        'long': 'x' * 41,
        'ok': 'income',
      });
      expect(out, {'ok': 'income'});
    });

    test('drops unsupported value types and null', () {
      final out = AnalyticsSanitizer.sanitize({
        'list': [1, 2],
        'map': {'a': 1},
        'nothing': null,
        'when': DateTime(2026),
      });
      expect(out, isEmpty);
    });

    test('rejects invalid parameter names and caps the count', () {
      final params = <String, Object?>{
        'bad key': 1,
        '1leading': 1,
        for (var i = 0; i < 40; i++) 'p$i': i,
      };
      final out = AnalyticsSanitizer.sanitize(params);
      expect(out.containsKey('bad key'), isFalse);
      expect(out.containsKey('1leading'), isFalse);
      expect(out.length, 25);
    });

    test('validates event names', () {
      expect(AnalyticsSanitizer.isValidEventName('task_created'), isTrue);
      expect(AnalyticsSanitizer.isValidEventName('Task Created'), isFalse);
      expect(AnalyticsSanitizer.isValidEventName(''), isFalse);
      expect(AnalyticsSanitizer.isValidEventName('1abc'), isFalse);
      expect(AnalyticsSanitizer.isValidEventName('a' * 41), isFalse);
    });
  });

  group('services', () {
    test('default instance is a safe no-op', () async {
      await AnalyticsService.instance.logEvent('task_created', {'x': 1});
      await AnalyticsService.instance.setUserId('u');
    });

    test('recording service stores sanitized events only', () async {
      final analytics = RecordingAnalyticsService();
      await analytics.logEvent(AnalyticsEvents.transactionAdded, {
        'kind': 'expense',
        'amount': 99.0,
        'title': 'Coffee',
      });
      await analytics.logEvent('not valid', {'a': 1});

      expect(analytics.events, hasLength(1));
      expect(analytics.events.single.name, 'transaction_added');
      expect(analytics.events.single.params, {'kind': 'expense'});
    });

    test('event names are the documented set', () {
      expect({
        AnalyticsEvents.signUp,
        AnalyticsEvents.login,
        AnalyticsEvents.taskCreated,
        AnalyticsEvents.taskCompleted,
        AnalyticsEvents.noteCreated,
        AnalyticsEvents.habitCompleted,
        AnalyticsEvents.transactionAdded,
        AnalyticsEvents.focusSessionCompleted,
      }, hasLength(8));
      for (final n in [
        AnalyticsEvents.signUp,
        AnalyticsEvents.focusSessionCompleted,
      ]) {
        expect(AnalyticsSanitizer.isValidEventName(n), isTrue);
      }
    });
  });

  group('CrashReporter', () {
    test('hashed user id is stable, short and hides the uid', () {
      final a = hashedUserId('uid-123');
      expect(a, hashedUserId('uid-123'));
      expect(a, isNot(contains('uid')));
      expect(a.length, 24);
      expect(a, isNot(hashedUserId('uid-124')));
    });

    test('default reporter is a no-op', () async {
      await CrashReporter.instance.setUser('u1');
      await CrashReporter.instance.recordError(StateError('x'), null);
    });
  });
}
