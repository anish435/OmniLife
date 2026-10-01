import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/pages/auth/login_page.dart';

import '../controllers/auth_controller_test.dart' show FakeAuthRepository;

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  Future<void> pumpLoginPage(WidgetTester tester, AuthRepository fake) async {
    Get.put<AuthController>(AuthController(authRepository: fake));
    await tester.pumpWidget(const GetMaterialApp(home: LoginPage()));
    await tester.pump();
  }

  testWidgets('shows validation errors on empty submit', (tester) async {
    await pumpLoginPage(tester, FakeAuthRepository());

    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows validation error for an invalid email', (tester) async {
    await pumpLoginPage(tester, FakeAuthRepository());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('renders Continue with Google button and triggers sign in', (tester) async {
    final fake = FakeAuthRepository();
    await pumpLoginPage(tester, fake);

    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    final controller = Get.find<AuthController>();
    expect(controller.status.value, AuthStatus.authenticated);
  });
}
