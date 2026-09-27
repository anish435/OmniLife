import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Thin wrapper around [fb.FirebaseAuth]. Contains no business rules —
/// only direct SDK calls, so the repository layer above it is the only
/// place that translates Firebase-specific results/errors.
class FirebaseAuthDataSource {
  FirebaseAuthDataSource({fb.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _firebaseAuth;

  Stream<fb.User?> authStateChanges() => _firebaseAuth.authStateChanges();

  fb.User? get currentUser => _firebaseAuth.currentUser;

  Future<fb.User> register({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  Future<fb.User> login({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  Future<void> logout() => _firebaseAuth.signOut();
}
