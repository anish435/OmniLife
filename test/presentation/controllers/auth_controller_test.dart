import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/errors/failures.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  Object? failureToThrowOnRegister;
  Object? failureToThrowOnLogin;

  void emit(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    // Mirror real Firebase behavior: a new listener immediately receives
    // the current state, not just future changes.
    yield _current;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    if (failureToThrowOnRegister != null) throw failureToThrowOnRegister!;
    final user = AppUser(uid: 'new-uid', email: email);
    emit(user);
    return user;
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (failureToThrowOnLogin != null) throw failureToThrowOnLogin!;
    final user = AppUser(uid: 'uid', email: email);
    emit(user);
    return user;
  }

  @override
  Future<void> logout() async {
    emit(null);
  }

  void dispose() => _controller.close();
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  test(
    'starts initializing, then unauthenticated with no signed-in user',
    () async {
      final fake = FakeAuthRepository();
      final controller = AuthController(authRepository: fake);
      controller.onInit();

      expect(controller.status.value, AuthStatus.initializing);
      await Future<void>.delayed(Duration.zero);
      expect(controller.status.value, AuthStatus.unauthenticated);

      fake.dispose();
    },
  );

  test('reflects authenticated status when repository emits a user', () async {
    final fake = FakeAuthRepository();
    final controller = AuthController(authRepository: fake);
    controller.onInit();

    fake.emit(const AppUser(uid: 'uid-1', email: 'user@example.com'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.status.value, AuthStatus.authenticated);
    expect(controller.currentUser.value?.email, 'user@example.com');

    fake.dispose();
  });

  test('login failure surfaces the message and clears loading', () async {
    final fake = FakeAuthRepository()
      ..failureToThrowOnLogin = const AuthFailure('Invalid credentials');
    final controller = AuthController(authRepository: fake);
    controller.onInit();

    await controller.login(email: 'user@example.com', password: 'wrongpass');

    expect(controller.errorMessage.value, 'Invalid credentials');
    expect(controller.isLoading.value, isFalse);

    fake.dispose();
  });

  test('successful register clears error and reaches authenticated', () async {
    final fake = FakeAuthRepository();
    final controller = AuthController(authRepository: fake);
    controller.onInit();

    await controller.register(
      email: 'new@example.com',
      password: 'password123',
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.errorMessage.value, isNull);
    expect(controller.status.value, AuthStatus.authenticated);

    fake.dispose();
  });

  test('logout drives status back to unauthenticated', () async {
    final fake = FakeAuthRepository();
    final controller = AuthController(authRepository: fake);
    controller.onInit();

    fake.emit(const AppUser(uid: 'uid-1', email: 'user@example.com'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.status.value, AuthStatus.authenticated);

    await controller.logout();
    await Future<void>.delayed(Duration.zero);
    expect(controller.status.value, AuthStatus.unauthenticated);

    fake.dispose();
  });
}
