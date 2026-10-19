import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_spacing.dart';

/// Responsive scaffold shell supporting:
/// - Web / Desktop (>= 1000): side navigation rail + centered content (max-width 1100)
/// - Tablet (600 - 1000): compact navigation rail + centered content
/// - Mobile (< 600): bottom bar with the main places and a "More" sheet for
///   the rest, so nothing is squeezed at 375px.
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
    NavDestination(
      AppRoutes.dashboard,
      Icons.dashboard_outlined,
      Icons.dashboard,
      'Dashboard',
    ),
    NavDestination(
      AppRoutes.tasks,
      Icons.check_box_outlined,
      Icons.check_box,
      'Tasks',
    ),
    NavDestination(
      AppRoutes.calendar,
      Icons.calendar_today_outlined,
      Icons.calendar_today,
      'Calendar',
    ),
    NavDestination(AppRoutes.notes, Icons.notes_outlined, Icons.notes, 'Notes'),
    NavDestination(
      AppRoutes.habits,
      Icons.track_changes_outlined,
      Icons.track_changes,
      'Habits',
    ),
    NavDestination(
      AppRoutes.finance,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Finance',
    ),
    NavDestination(
      AppRoutes.wellness,
      Icons.self_improvement_outlined,
      Icons.self_improvement,
      'Wellness',
    ),
    NavDestination(
      AppRoutes.pulse,
      Icons.timeline_outlined,
      Icons.timeline,
      'Pulse',
    ),
    NavDestination(AppRoutes.focus, Icons.timer_outlined, Icons.timer, 'Focus'),
    NavDestination(AppRoutes.map, Icons.map_outlined, Icons.map, 'Map'),
    NavDestination(
      AppRoutes.sensors,
      Icons.sensors_outlined,
      Icons.sensors,
      'Sensors',
    ),
    NavDestination(
      AppRoutes.insights,
      Icons.show_chart,
      Icons.show_chart,
      'Insights',
    ),
  ];

  /// Routes shown directly in the mobile bottom bar. Everything else in
  /// [destinations] is reached through the "More" sheet.
  static const mobilePrimaryRoutes = [
    AppRoutes.dashboard,
    AppRoutes.tasks,
    AppRoutes.pulse,
    AppRoutes.focus,
  ];

  static List<NavDestination> get mobilePrimary => [
    for (final route in mobilePrimaryRoutes)
      destinations.firstWhere((d) => d.route == route),
  ];

  static List<NavDestination> get mobileMore => [
    for (final d in destinations)
      if (!mobilePrimaryRoutes.contains(d.route)) d,
  ];

  String get _activeRoute {
    if (currentRoute != null) return currentRoute!;
    if (selectedIndex >= 0 && selectedIndex < destinations.length) {
      return destinations[selectedIndex].route;
    }
    return AppRoutes.dashboard;
  }

  void _go(String target) {
    if (Get.currentRoute != target) {
      Get.toNamed(target);
    }
  }

  void _onNavigate(int index) {
    if (index >= 0 && index < destinations.length) {
      _go(destinations[index].route);
    }
  }

  int get _railIndex {
    final i = destinations.indexWhereRoute(_activeRoute);
    return i < 0 ? 0 : i;
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
            // Scrolls when the window is too short for every destination.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _railIndex,
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
                  ),
                ),
              ),
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

    final primary = mobilePrimary;
    final activePrimary = primary.indexWhere((d) => d.route == _activeRoute);
    // The "More" tab lights up when the open page lives in the sheet.
    final barIndex = activePrimary >= 0 ? activePrimary : primary.length;

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: body,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: barIndex,
        onDestinationSelected: (i) {
          if (i < primary.length) {
            _go(primary[i].route);
          } else {
            _showMore(context);
          }
        },
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.activeIcon),
              label: d.label,
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    'More places',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                for (final d in mobileMore)
                  ListTile(
                    leading: Icon(d.icon),
                    title: Text(d.label),
                    selected: d.route == _activeRoute,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _go(d.route);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on List<NavDestination> {
  int indexWhereRoute(String route) => indexWhere((d) => d.route == route);
}

class NavDestination {
  const NavDestination(this.route, this.icon, this.activeIcon, this.label);
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
