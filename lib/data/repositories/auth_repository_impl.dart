import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/firebase_auth_datasource.dart';

/// [AuthRepository] implementation backed by Firebase Authentication.
///
/// Translates `firebase_auth` exceptions into [AuthFailure]s so the rest
/// of the app never needs to catch `FirebaseAuthException` directly.
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

  @override
  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dataSource.register(email: email, password: password);
      return _toAppUser(user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Registration failed.', code: e.code);
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dataSource.login(email: email, password: password);
      return _toAppUser(user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Login failed.', code: e.code);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final user = await _dataSource.signInWithGoogle();
      return _toAppUser(user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Google sign-in failed.', code: e.code);
    }
  }

  @override
  Future<void> logout() => _dataSource.logout();

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
