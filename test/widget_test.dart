import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:omnilife/app/app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  testWidgets('App shell boots and reaches Login when unauthenticated', (
    WidgetTester tester,
  ) async {
    // No Firebase is configured in this test environment, so the auth
    // stream never resolves to a signed-in user — the app should still
    // boot cleanly and land on Login rather than crash.
    await tester.pumpWidget(const OmniLifeApp());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('OmniLife'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
