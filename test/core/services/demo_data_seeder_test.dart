import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:omnilife/core/services/demo_data_seeder.dart';
import 'package:omnilife/domain/repositories/auth_repository.dart';
import 'package:omnilife/presentation/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/controllers/task_controller_test.dart'
    show FakeAuthRepository;

void main() {
  late AuthController auth;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    DemoDataSeeder.isDemoMode.value = false;
    auth = AuthController(authRepository: FakeAuthRepository());
    Get.put<AuthController>(auth);
  });

  tearDown(Get.reset);

  const alice = AppUser(uid: 'alice', email: 'a@example.com');
  const bob = AppUser(uid: 'bob', email: 'b@example.com');

  test('signed out: loading refuses with a plain message', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await DemoDataSeeder.seedAll(), isFalse);
    expect(DemoDataSeeder.lastError, DemoDataSeeder.signInMessage);
    expect(DemoDataSeeder.isDemoMode.value, isFalse);
  });

  test('sample data state is kept per account', () async {
    SharedPreferences.setMockInitialValues({
      'omnilife_demo_mode_active_alice': true,
    });

    auth.currentUser.value = alice;
    await DemoDataSeeder.checkStatus();
    expect(DemoDataSeeder.isDemoMode.value, isTrue);

    auth.currentUser.value = bob;
    await DemoDataSeeder.checkStatus();
    expect(DemoDataSeeder.isDemoMode.value, isFalse);

    auth.currentUser.value = alice;
    await DemoDataSeeder.checkStatus();
    expect(DemoDataSeeder.isDemoMode.value, isTrue);
  });

  test('loading twice does nothing the second time', () async {
    SharedPreferences.setMockInitialValues({});
    auth.currentUser.value = alice;

    expect(await DemoDataSeeder.seedAll(), isTrue);
    expect(DemoDataSeeder.isDemoMode.value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('omnilife_demo_mode_active_alice'), isTrue);
    expect(prefs.getBool('omnilife_demo_mode_active_bob'), isNull);

    // Second call returns early because the flag for this account is set.
    expect(await DemoDataSeeder.seedAll(), isTrue);
  });

  test('removing clears only this accounts flag', () async {
    SharedPreferences.setMockInitialValues({
      'omnilife_demo_mode_active_alice': true,
      'omnilife_demo_mode_active_bob': true,
    });
    auth.currentUser.value = alice;
    await DemoDataSeeder.checkStatus();

    expect(await DemoDataSeeder.clearDemoData(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('omnilife_demo_mode_active_alice'), isFalse);
    expect(prefs.getBool('omnilife_demo_mode_active_bob'), isTrue);
    expect(DemoDataSeeder.isDemoMode.value, isFalse);
  });
}
