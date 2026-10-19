// ignore_for_file: prefer_initializing_formals
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../presentation/controllers/auth_controller.dart';
import 'app_routes.dart';

/// Keeps signed-out people out of the app and signed-in people out of the
/// sign-in screens.
///
/// - Protected route + signed out  -> login (remembering the route)
/// - Protected route + still checking the session -> splash (remembering it)
/// - Login/register + signed in -> dashboard
///
/// The splash route is never guarded. When the session settles,
/// [AuthController] sends the person to [takePendingRoute] if one was
/// remembered, so a web deep link such as `#/pulse` survives the sign-in
/// check instead of being replaced by the dashboard.
class AuthGuard extends GetMiddleware {
  AuthGuard({AuthStatus? Function()? statusProvider})
    : _statusProvider = statusProvider,
      super(priority: 1);

  final AuthStatus? Function()? _statusProvider;

  static const _open = {AppRoutes.splash};
  static const _guestOnly = {AppRoutes.login, AppRoutes.register};

  static String? _pendingRoute;

  /// Route a signed-out visitor asked for, to resume after sign-in.
  static String? get pendingRoute => _pendingRoute;

  static String? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  @visibleForTesting
  static void clearPendingRoute() => _pendingRoute = null;

  /// Returns [pages] with an [AuthGuard] attached to every route except
  /// the splash screen.
  static List<GetPage<dynamic>> protect(
    List<GetPage<dynamic>> pages, {
    AuthStatus? Function()? statusProvider,
  }) {
    return [
      for (final page in pages)
        if (_open.contains(page.name))
          page
        else
          page.copy(
            middlewares: [
              ...?page.middlewares,
              AuthGuard(statusProvider: statusProvider),
            ],
          ),
    ];
  }

  AuthStatus? _status() {
    final provider = _statusProvider;
    if (provider != null) return provider();
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>().status.value;
  }

  @override
  RouteSettings? redirect(String? route) {
    final path = Uri.tryParse(route ?? '')?.path ?? route ?? '';
    if (_open.contains(path)) return null;

    final status = _status();
    // No auth controller (isolated widget tests): do not block anything.
    if (status == null) return null;

    if (_guestOnly.contains(path)) {
      return status == AuthStatus.authenticated
          ? const RouteSettings(name: AppRoutes.dashboard)
          : null;
    }

    switch (status) {
      case AuthStatus.authenticated:
        return null;
      case AuthStatus.initializing:
        _pendingRoute = route;
        return const RouteSettings(name: AppRoutes.splash);
      case AuthStatus.unauthenticated:
        _pendingRoute = route;
        return const RouteSettings(name: AppRoutes.login);
    }
  }
}
