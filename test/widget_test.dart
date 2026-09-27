import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:omnilife/app/app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  testWidgets('App shell boots, shows splash then dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OmniLifeApp());
    await tester.pump();

    expect(find.text('OmniLife'), findsOneWidget);

    // Let the splash page's post-boot navigation to the dashboard settle.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
