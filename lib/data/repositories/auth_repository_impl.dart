import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart' show PlatformException;

import '../../core/errors/auth_error_messages.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/firebase_auth_datasource.dart';

/// [AuthRepository] implementation backed by Firebase Authentication.
///
/// Translates `firebase_auth` exceptions into [AuthFailure]s carrying a
/// plain-language message, so the rest of the app never shows (or needs to
/// catch) raw SDK errors.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({FirebaseAuthDataSource? dataSource})
    : _dataSource = dataSource ?? FirebaseAuthDataSource();

  final FirebaseAuthDataSource _dataSource;

  @override
  Stream<AppUser?> authStateChanges() {
    return _dataSource.authStateChanges().map(_toAppUser);
  }

  @override
  AppUser? get currentUser => _toAppUser(_dataSource.currentUser);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(
        friendlyAuthMessage(e.code, fallback: e.message),
        code: e.code,
      );
    } on PlatformException catch (e) {
      // google_sign_in reports problems this way (network_error, etc.).
      final code = e.code == 'network_error'
          ? 'network-request-failed'
          : e.code;
      throw AuthFailure(
        friendlyAuthMessage(code, fallback: e.message),
        code: code,
      );
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw AuthFailure(friendlyAuthMessage(null), code: 'unknown');
    }
  }

  @override
  Future<AppUser> register({required String email, required String password}) =>
      _guard(() async {
        final user = await _dataSource.register(
          email: email,
          password: password,
        );
        return _toAppUser(user)!;
      });

  @override
  Future<AppUser> login({required String email, required String password}) =>
      _guard(() async {
        final user = await _dataSource.login(email: email, password: password);
        return _toAppUser(user)!;
      });

  @override
  Future<AppUser> signInWithGoogle() => _guard(() async {
    final user = await _dataSource.signInWithGoogle();
    return _toAppUser(user)!;
  });

  @override
  Future<void> logout() => _dataSource.logout();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _guard(() => _dataSource.sendPasswordResetEmail(email));

  AppUser? _toAppUser(fb.User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
