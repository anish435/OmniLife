import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/app/theme/app_theme.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:omnilife/presentation/pages/auth/login_page.dart';
import 'package:omnilife/presentation/widgets/auth/auth_toggle.dart';
import 'package:omnilife/presentation/widgets/auth/omnilife_auth_background.dart';
import 'package:omnilife/presentation/widgets/auth/social_auth_button.dart';

import '../controllers/auth_controller_test.dart' show FakeAuthRepository;

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpAuthApp(
    WidgetTester tester, {
    AuthRepository? fakeRepo,
    ThemeData? theme,
    AuthMode initialMode = AuthMode.signIn,
  }) async {
    final repo = fakeRepo ?? FakeAuthRepository();
    Get.put<AuthController>(AuthController(authRepository: repo));

    await tester.pumpWidget(
      GetMaterialApp(
        theme: theme ?? AppTheme.light,
        home: LoginPage(initialMode: initialMode),
      ),
    );
    await tester.pump();
  }

  // 1. Login Validation Test
  testWidgets('1. Login validation shows appropriate field error messages', (tester) async {
    await pumpAuthApp(tester);

    final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.ensureVisible(signInBtn);
    await tester.tap(signInBtn);
    await tester.pump();

    // Verify empty validations
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    // Verify invalid email format validation
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'notanemail');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'validpassword123');
    await tester.tap(signInBtn);
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  // 2. Password Visibility Test
  testWidgets('2. Password visibility toggles between obscure and revealed text', (tester) async {
    await pumpAuthApp(tester);

    // Initially password field is obscured
    final passwordFieldFinder = find.widgetWithText(TextFormField, 'Password');
    final textFieldFinder = find.descendant(of: passwordFieldFinder, matching: find.byType(TextField));
    expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);

    // Tap show password icon
    final visibilityIcon = find.byTooltip('Show password');
    expect(visibilityIcon, findsOneWidget);
    await tester.tap(visibilityIcon);
    await tester.pump();

    // Field is now revealed
    expect(tester.widget<TextField>(textFieldFinder).obscureText, isFalse);

    // Tap hide password icon
    final hideIcon = find.byTooltip('Hide password');
    expect(hideIcon, findsOneWidget);
    await tester.tap(hideIcon);
    await tester.pump();

    // Field is obscured again
    expect(tester.widget<TextField>(textFieldFinder).obscureText, isTrue);
  });

  // 3. Sign In <-> Sign Up Animated Switching Test
  testWidgets('3. Smooth transition between Sign In and Sign Up modes', (tester) async {
    await pumpAuthApp(tester);

    // Initial Sign In state
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Confirm password'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);

    // Tap Sign Up segment on AuthToggle
    final signUpToggle = find.widgetWithText(InkWell, 'Sign Up');
    expect(signUpToggle, findsOneWidget);
    await tester.tap(signUpToggle);
    await tester.pumpAndSettle();

    // Now in Sign Up state
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Confirm password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);

    // Tap Sign In segment to return
    final signInToggle = find.widgetWithText(InkWell, 'Sign In');
    await tester.tap(signInToggle);
    await tester.pumpAndSettle();

    // Back to Sign In state
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Confirm password'), findsNothing);
  });

  // 4. Forgot Password Flow Test
  testWidgets('4. Forgot password sheet opens, validates, and sends recovery email', (tester) async {
    final fakeRepo = FakeAuthRepository();
    await pumpAuthApp(tester, fakeRepo: fakeRepo);

    // Type email in login form first to test prefill
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'user@example.com');

    // Tap "Forgot password?"
    final forgotBtn = find.text('Forgot password?');
    await tester.ensureVisible(forgotBtn);
    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();

    // Verify ForgotPasswordSheet is rendered with prefilled email
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('user@example.com'), findsWidgets);

    // Tap Send Reset Link
    final sendResetBtn = find.widgetWithText(FilledButton, 'Send Reset Link');
    await tester.tap(sendResetBtn);
    await tester.pumpAndSettle();

    // Verify recovery instructions sent and success message displayed
    expect(fakeRepo.lastResetEmailSent, 'user@example.com');
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Back to Sign In'), findsOneWidget);

    // Tap back to sign in closes sheet
    await tester.tap(find.text('Back to Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsNothing);
  });

  // 5. Loading States Test
  testWidgets('5. Loading states disable buttons and show progress indicators', (tester) async {
    await pumpAuthApp(tester);

    final controller = Get.find<AuthController>();

    // Primary action loading
    controller.isLoading.value = true;
    await tester.pump();

    final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(elevatedButton.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.isLoading.value = false;
    await tester.pump();

    // Google button loading
    controller.isGoogleLoading.value = true;
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.isGoogleLoading.value = false;
    await tester.pump();
  });

  // 6. Authentication Errors Test
  testWidgets('6. Authentication error surfaces in styled alert banner', (tester) async {
    await pumpAuthApp(tester);

    final controller = Get.find<AuthController>();
    controller.errorMessage.value = 'Invalid email or password.';
    await tester.pump();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    // Clear error
    controller.clearError();
    await tester.pump();

    expect(find.text('Invalid email or password.'), findsNothing);
  });

  // 7. Successful Navigation Test
  testWidgets('7. Successful authentication triggers status change to authenticated', (tester) async {
    final fakeRepo = FakeAuthRepository();
    await pumpAuthApp(tester, fakeRepo: fakeRepo);

    final controller = Get.find<AuthController>();
    expect(controller.status.value, AuthStatus.unauthenticated);

    // Trigger google sign in
    final googleBtn = find.byType(SocialAuthButton);
    await tester.ensureVisible(googleBtn);
    await tester.tap(googleBtn);
    await tester.pump();

    expect(controller.status.value, AuthStatus.authenticated);
  });

  // 8. Light/Dark Themes Test
  testWidgets('8. Renders cleanly in both Light and Dark themes', (tester) async {
    // Light Mode
    await pumpAuthApp(tester, theme: AppTheme.light);
    expect(find.byType(OmniLifeAuthBackground), findsOneWidget);
    expect(find.text('OmniLife'), findsOneWidget);

    // Dark Mode
    Get.reset();
    await pumpAuthApp(tester, theme: AppTheme.dark);
    expect(find.byType(OmniLifeAuthBackground), findsOneWidget);
    expect(find.text('OmniLife'), findsOneWidget);
  });

  // 9. Keyboard Behavior and Scrollability Test
  testWidgets('9. Adapts safely within SingleChildScrollView on small viewports', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpAuthApp(tester);

    final scrollable = find.byType(SingleChildScrollView);
    expect(scrollable, findsOneWidget);

    // Can scroll down to find Google button
    final googleBtn = find.byType(SocialAuthButton);
    await tester.ensureVisible(googleBtn);
    expect(googleBtn, findsOneWidget);
  });

  // 10. Animation Disposal / Performance Test
  testWidgets('10. Background and card animations dispose without throwing exceptions', (tester) async {
    await pumpAuthApp(tester);

    // Pump a different widget to trigger full disposal of LoginPage and its AnimationControllers
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Replaced'))));
    await tester.pump();

    expect(find.text('Replaced'), findsOneWidget);
  });
}
