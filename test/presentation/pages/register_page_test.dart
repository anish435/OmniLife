import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/pages/auth/register_page.dart';

import '../controllers/auth_controller_test.dart' show FakeAuthRepository;

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  Future<void> pumpRegisterPage(
    WidgetTester tester,
    AuthRepository fake,
  ) async {
    Get.put<AuthController>(AuthController(authRepository: fake));
    await tester.pumpWidget(const GetMaterialApp(home: RegisterPage()));
    await tester.pump();
  }

  testWidgets('rejects mismatched passwords', (tester) async {
    await pumpRegisterPage(tester, FakeAuthRepository());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'different123',
    );
    final signUpBtn = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.ensureVisible(signUpBtn);
    await tester.tap(signUpBtn);
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    await pumpRegisterPage(tester, FakeAuthRepository());

    final signUpBtn = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.ensureVisible(signUpBtn);
    await tester.tap(signUpBtn);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm password is required'), findsOneWidget);
  });
}
