import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/errors/auth_error_messages.dart';
import 'package:omnilife/core/errors/failures.dart';
import 'package:omnilife/data/datasources/remote/firebase_auth_datasource.dart';
import 'package:omnilife/data/repositories/auth_repository_impl.dart';

class _ThrowingDataSource implements FirebaseAuthDataSource {
  _ThrowingDataSource(this.error);
  final Object error;

  @override
  Future<fb.User> login({required String email, required String password}) =>
      Future.error(error);
  @override
  Future<fb.User> register({required String email, required String password}) =>
      Future.error(error);
  @override
  Future<fb.User> signInWithGoogle() => Future.error(error);
  @override
  Future<void> sendPasswordResetEmail(String email) => Future.error(error);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('friendlyAuthMessage', () {
    test('maps the common codes to plain sentences', () {
      expect(
        friendlyAuthMessage('wrong-password'),
        'Email or password is incorrect.',
      );
      expect(friendlyAuthMessage('user-not-found'), contains('incorrect'));
      expect(
        friendlyAuthMessage('email-already-in-use'),
        contains('already exists'),
      );
      expect(friendlyAuthMessage('weak-password'), contains('6 characters'));
      expect(
        friendlyAuthMessage('network-request-failed'),
        contains('internet'),
      );
      expect(friendlyAuthMessage('too-many-requests'), contains('wait'));
    });

    test('unknown codes never leak the code itself', () {
      final text = friendlyAuthMessage('some-new-firebase-code');
      expect(text, 'Something went wrong. Please try again.');
      expect(text, isNot(contains('firebase')));
    });
  });

  group('AuthRepositoryImpl error mapping', () {
    Future<AuthFailure> failureFrom(
      Object error,
      Future<void> Function(AuthRepositoryImpl) call,
    ) async {
      final repo = AuthRepositoryImpl(dataSource: _ThrowingDataSource(error));
      try {
        await call(repo);
      } on AuthFailure catch (f) {
        return f;
      }
      fail('expected an AuthFailure');
    }

    final raw = fb.FirebaseAuthException(
      code: 'wrong-password',
      message: '[firebase_auth/wrong-password] The password is invalid.',
    );

    test('login hides the raw SDK message', () async {
      final f = await failureFrom(
        raw,
        (r) => r.login(email: 'a@b.co', password: 'x'),
      );
      expect(f.message, 'Email or password is incorrect.');
      expect(f.code, 'wrong-password');
    });

    test('register maps email-already-in-use', () async {
      final f = await failureFrom(
        fb.FirebaseAuthException(code: 'email-already-in-use', message: 'raw'),
        (r) => r.register(email: 'a@b.co', password: 'secret1'),
      );
      expect(f.message, contains('already exists'));
    });

    test('reset password maps invalid-email', () async {
      final f = await failureFrom(
        fb.FirebaseAuthException(code: 'invalid-email', message: 'raw'),
        (r) => r.sendPasswordResetEmail('nope'),
      );
      expect(f.message, contains('email address'));
    });

    test(
      'google maps platform and unexpected errors without raw text',
      () async {
        final net = await failureFrom(
          PlatformException(code: 'network_error', message: 'raw text'),
          (r) => r.signInWithGoogle(),
        );
        expect(net.message, contains('internet'));
        final other = await failureFrom(
          StateError('boom stack'),
          (r) => r.signInWithGoogle(),
        );
        expect(other.message, isNot(contains('boom')));
        expect(other.message, contains('Something went wrong'));
      },
    );
  });
}
