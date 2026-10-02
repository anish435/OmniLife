import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around [fb.FirebaseAuth] and [GoogleSignIn]. Contains no business rules —
/// only direct SDK calls, so the repository layer above it is the only
/// place that translates Firebase-specific results/errors.
class FirebaseAuthDataSource {
  FirebaseAuthDataSource({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _injectedGoogleSignIn = googleSignIn;

  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn? _injectedGoogleSignIn;

  GoogleSignIn get _googleSignIn =>
      _injectedGoogleSignIn ?? GoogleSignIn();

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

  Future<fb.User> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = fb.GoogleAuthProvider()..addScope('email');
      final credential = await _firebaseAuth.signInWithPopup(googleProvider);
      if (credential.user == null) {
        throw fb.FirebaseAuthException(
          code: 'ERROR_NO_USER',
          message: 'Google sign-in completed without returning a user.',
        );
      }
      return credential.user!;
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw fb.FirebaseAuthException(
          code: 'canceled',
          message: 'Sign in was canceled by the user.',
        );
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      if (userCredential.user == null) {
        throw fb.FirebaseAuthException(
          code: 'ERROR_NO_USER',
          message: 'Google sign-in completed without returning a user.',
        );
      }
      return userCredential.user!;
    }
  }

  Future<void> logout() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await _firebaseAuth.signOut();
  }
}

