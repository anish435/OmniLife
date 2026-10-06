/// Route name constants. Feature routes are added here as they are built —
/// this file is the single place that names a route.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const tasks = '/tasks';
  static const calendar = '/calendar';
  static const notes = '/notes';
  static const habits = '/habits';
  static const finance = '/finance';
  static const wellness = '/wellness';
  static const pulse = '/pulse';
  static const insights = '/insights';
  static const sleep = '/sleep';
  // START: focus mode
  static const focus = '/focus';
  // END: focus mode

  // --- Maps / GPS and Sensors modules (additive) ---
  static const map = '/map';
  static const sensors = '/sensors';
}
