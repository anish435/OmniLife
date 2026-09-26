/// Minimal, framework-agnostic representation of the signed-in user.
///
/// Kept separate from any Firebase type so domain/presentation code never
/// depends on `firebase_auth` directly.
class AppUser {
  const AppUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

/// Domain-facing contract for authentication.
///
/// Implementations live in the data layer. UI/state-management code must
/// depend on this interface, never on Firebase Auth directly.
abstract class AuthRepository {
  /// Emits the current user (or `null` when signed out) whenever the
  /// auth state changes.
  Stream<AppUser?> authStateChanges();

  /// The currently signed-in user, if any.
  AppUser? get currentUser;

  Future<AppUser> register({required String email, required String password});

  Future<AppUser> login({required String email, required String password});

  Future<void> logout();
}
