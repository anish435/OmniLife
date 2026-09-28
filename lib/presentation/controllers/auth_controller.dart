import 'dart:async';

import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/auth_repository.dart';

/// Application-level authentication state, per docs/architecture.md §3
/// (GetX owns auth/session state).
enum AuthStatus { initializing, unauthenticated, authenticated }

/// Presentation-layer auth state/orchestration.
///
/// Never calls Firebase directly — everything goes through
/// [AuthRepository], which is the only thing this controller depends on.
/// Observes [AuthRepository.authStateChanges] so the rest of the app
/// (routing, dashboard) reacts to auth changes rather than being told
/// about them imperatively.
class AuthController extends GetxController {
  AuthController({AuthRepository? authRepository})
    : _injectedRepository = authRepository;

  /// Only set in tests, to bypass `Get.find` and inject a fake.
  final AuthRepository? _injectedRepository;
  AuthRepository? _authRepository;

  StreamSubscription<AppUser?>? _authSubscription;

  final status = AuthStatus.initializing.obs;
  final currentUser = Rxn<AppUser>();
  final isLoading = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    try {
      _authRepository = _injectedRepository ?? Get.find<AuthRepository>();
      _authSubscription = _authRepository!.authStateChanges().listen(
        _onAuthStateChanged,
        onError: (_) => status.value = AuthStatus.unauthenticated,
      );
    } catch (_) {
      // Firebase isn't configured for this environment (see
      // docs/firebase-setup.md) — fail to "signed out" rather than crash.
      status.value = AuthStatus.unauthenticated;
    }
  }

  void _onAuthStateChanged(AppUser? user) {
    currentUser.value = user;
    status.value = user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
  }

  /// Routing reacts to auth status rather than screens navigating
  /// imperatively after login/logout — this is the single place that
  /// decision is made, avoiding redirect loops.
  @override
  void onReady() {
    super.onReady();
    ever<AuthStatus>(status, _redirectForStatus);
    // `ever` only fires on future changes; handle a status that already
    // settled (e.g. Firebase unavailable, set synchronously in onInit)
    // before this listener was attached.
    _redirectForStatus(status.value);
  }

  void _redirectForStatus(AuthStatus value) {
    // Guarded: in unit tests this controller can be exercised without a
    // mounted GetMaterialApp/navigator, where routing calls are a no-op
    // failure rather than something worth crashing over.
    try {
      switch (value) {
        case AuthStatus.initializing:
          break;
        case AuthStatus.unauthenticated:
          Get.offAllNamed(AppRoutes.login);
        case AuthStatus.authenticated:
          Get.offAllNamed(AppRoutes.dashboard);
      }
    } catch (_) {}
  }

  Future<void> register({required String email, required String password}) =>
      _runAuthAction(
        () => _authRepository!.register(email: email, password: password),
      );

  Future<void> login({required String email, required String password}) =>
      _runAuthAction(
        () => _authRepository!.login(email: email, password: password),
      );

  Future<void> logout() async {
    if (_authRepository == null) return;
    await _authRepository!.logout();
  }

  void clearError() => errorMessage.value = null;

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_authRepository == null) {
      errorMessage.value =
          'Authentication is unavailable: Firebase has not been configured '
          'for this environment.';
      return;
    }
    errorMessage.value = null;
    isLoading.value = true;
    try {
      await action();
    } on AuthFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Something went wrong. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
