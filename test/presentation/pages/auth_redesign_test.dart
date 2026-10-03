import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/pages/auth/login_page.dart';
import 'package:omnilife/presentation/pages/auth/register_page.dart';
import 'package:omnilife/presentation/widgets/auth/forgot_password_dialog.dart';
import 'package:omnilife/presentation/widgets/auth/omnilife_auth_background.dart';
import 'package:omnilife/presentation/widgets/google_sign_in_button.dart';

import '../controllers/auth_controller_test.dart' show FakeAuthRepository;

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpLoginPage(
    WidgetTester tester, {
    AuthRepository? fakeRepo,
    ThemeData? theme,
  }) async {
    final repo = fakeRepo ?? FakeAuthRepository();
    Get.put<AuthController>(AuthController(authRepository: repo));

    await tester.pumpWidget(
      GetMaterialApp(
        theme: theme ?? AppTheme.light,
        home: const LoginPage(),
      ),
    );
    await tester.pump();
  }

  testWidgets('1. Login validation shows appropriate field error messages', (tester) async {
    await pumpLoginPage(tester);

    final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
    await tester.ensureVisible(loginBtn);
    await tester.tap(loginBtn);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
    await tester.tap(loginBtn);
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('2. Password visibility toggle works correctly', (tester) async {
    await pumpLoginPage(tester);

    final passwordFieldFinder = find.widgetWithText(TextFormField, 'Password');
    EditableText editable = tester.widget<EditableText>(
      find.descendant(of: passwordFieldFinder, matching: find.byType(EditableText)),
    );
    expect(editable.obscureText, isTrue);

    final toggleBtn = find.byTooltip('Show password');
    expect(toggleBtn, findsOneWidget);
    await tester.tap(toggleBtn);
    await tester.pump();

    editable = tester.widget<EditableText>(
      find.descendant(of: passwordFieldFinder, matching: find.byType(EditableText)),
    );
    expect(editable.obscureText, isFalse);

    final hideBtn = find.byTooltip('Hide password');
    expect(hideBtn, findsOneWidget);
    await tester.tap(hideBtn);
    await tester.pump();

    editable = tester.widget<EditableText>(
      find.descendant(of: passwordFieldFinder, matching: find.byType(EditableText)),
    );
    expect(editable.obscureText, isTrue);
  });

  testWidgets('3. Forgot password dialog opens, validates, and sends recovery email', (tester) async {
    final fake = FakeAuthRepository();
    await pumpLoginPage(tester, fakeRepo: fake);

    final forgotBtn = find.text('Forgot password?');
    expect(forgotBtn, findsOneWidget);
    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordDialog), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);

    final sendBtn = find.widgetWithText(ElevatedButton, 'Send reset link');
    await tester.tap(sendBtn);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);

    final emailInput = find.descendant(
      of: find.byType(ForgotPasswordDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(emailInput, 'reset@example.com');
    await tester.tap(sendBtn);
    await tester.pumpAndSettle();

    expect(find.text('Email sent'), findsOneWidget);

    final doneBtn = find.widgetWithText(ElevatedButton, 'Done');
    await tester.tap(doneBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordDialog), findsNothing);
  });

  testWidgets('4. Google sign-in triggers authentication flow', (tester) async {
    final fake = FakeAuthRepository();
    await pumpLoginPage(tester, fakeRepo: fake);

    final googleBtn = find.byType(GoogleSignInButton);
    expect(googleBtn, findsOneWidget);
    await tester.ensureVisible(googleBtn);
    await tester.tap(googleBtn);
    await tester.pump();

    final controller = Get.find<AuthController>();
    expect(controller.status.value, AuthStatus.authenticated);
  });

  testWidgets('5. Authentication errors surface properly in error text', (tester) async {
    await pumpLoginPage(tester);

    final controller = Get.find<AuthController>();
    controller.errorMessage.value = 'Invalid email or password.';
    await tester.pump();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('6. Register page renders and validates registration fields', (tester) async {
    final fake = FakeAuthRepository();
    Get.put<AuthController>(AuthController(authRepository: fake));

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const RegisterPage(),
      ),
    );
    await tester.pump();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    final registerBtn = find.widgetWithText(ElevatedButton, 'Register');
    await tester.ensureVisible(registerBtn);
    await tester.tap(registerBtn);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm password is required'), findsOneWidget);
  });

  testWidgets('7. Renders cleanly in both Light and Dark themes', (tester) async {
    // Light
    await pumpLoginPage(tester, theme: AppTheme.light);
    expect(find.byType(OmniLifeAuthBackground), findsOneWidget);
    expect(find.text('OmniLife'), findsOneWidget);

    // Dark
    Get.reset();
    Get.testMode = true;
    await pumpLoginPage(tester, theme: AppTheme.dark);
    expect(find.byType(OmniLifeAuthBackground), findsOneWidget);
    expect(find.text('OmniLife'), findsOneWidget);
  });

  testWidgets('8. Handles small screen viewports with SingleChildScrollView', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await pumpLoginPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('9. AnimationController disposes cleanly without throwing exceptions', (tester) async {
    await pumpLoginPage(tester);
    expect(find.byType(OmniLifeAuthBackground), findsOneWidget);

    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('Next Screen'))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
