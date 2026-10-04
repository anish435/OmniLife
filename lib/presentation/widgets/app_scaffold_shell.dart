import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';

/// Responsive scaffold shell supporting:
/// - Web / Desktop (>= 1000): side navigation rail + centered content (max-width 1100)
/// - Tablet (600 - 1000): compact navigation rail + centered content
/// - Mobile (< 600): standard bottom bar / scaffold
class AppScaffoldShell extends StatelessWidget {
  const AppScaffoldShell({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.currentRoute,
    this.selectedIndex = 0,
    this.maxWidth = 1100,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final String? currentRoute;
  final int selectedIndex;
  final double maxWidth;

  static const destinations = [
    _NavDestination(AppRoutes.dashboard, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    _NavDestination(AppRoutes.tasks, Icons.check_box_outlined, Icons.check_box, 'Tasks'),
    _NavDestination(AppRoutes.calendar, Icons.calendar_today_outlined, Icons.calendar_today, 'Calendar'),
    _NavDestination(AppRoutes.notes, Icons.notes_outlined, Icons.notes, 'Notes'),
    _NavDestination(AppRoutes.habits, Icons.track_changes_outlined, Icons.track_changes, 'Habits'),
    _NavDestination(AppRoutes.finance, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Finance'),
    _NavDestination(AppRoutes.wellness, Icons.self_improvement_outlined, Icons.self_improvement, 'Wellness'),
  ];

  void _onNavigate(int index) {
    if (index >= 0 && index < destinations.length) {
      final target = destinations[index].route;
      if (Get.currentRoute != target) {
        Get.toNamed(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1000;
    final isTablet = width >= 600 && width < 1000;

    if (isDesktop || isTablet) {
      return Scaffold(
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _onNavigate,
              extended: isDesktop && width >= 1200,
              minExtendedWidth: 200,
              labelType: (isDesktop && width >= 1200)
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.activeIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: body,
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.route, this.icon, this.activeIcon, this.label);
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
