import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/routes/app_routes.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/presentation/widgets/app_scaffold_shell.dart';

Widget _app(Size size, {String? route}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: GetMaterialApp(
      theme: AppTheme.light,
      home: AppScaffoldShell(
        currentRoute: route,
        body: const Center(child: Text('page body')),
      ),
      getPages: [
        for (final d in AppScaffoldShell.destinations)
          GetPage(name: d.route, page: () => Text('opened ${d.label}')),
      ],
    ),
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  test('Pulse, Focus, Map, Sensors and Insights are all destinations', () {
    final routes = AppScaffoldShell.destinations.map((d) => d.route).toSet();
    expect(
      routes,
      containsAll([
        AppRoutes.pulse,
        AppRoutes.focus,
        AppRoutes.map,
        AppRoutes.sensors,
        AppRoutes.insights,
        // The original places are kept.
        AppRoutes.dashboard,
        AppRoutes.tasks,
        AppRoutes.calendar,
        AppRoutes.notes,
        AppRoutes.habits,
        AppRoutes.finance,
        AppRoutes.wellness,
      ]),
    );
  });

  test('every destination is either in the bar or in the More sheet', () {
    final all = AppScaffoldShell.destinations.length;
    expect(
      AppScaffoldShell.mobilePrimary.length +
          AppScaffoldShell.mobileMore.length,
      all,
    );
    expect(AppScaffoldShell.mobilePrimary.length, lessThanOrEqualTo(4));
  });

  testWidgets('375px phone: bottom bar fits and More opens the rest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const Size(375, 812)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Pulse'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    // Not squeezed into the bar.
    expect(find.text('Sensors'), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    for (final label in ['Map', 'Sensors', 'Insights', 'Finance', 'Notes']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Sensors'));
    await tester.pumpAndSettle();
    expect(find.text('opened Sensors'), findsOneWidget);
  });

  testWidgets('tablet rail lists every destination without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const Size(800, 500)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Pulse'), findsOneWidget);
  });
}
