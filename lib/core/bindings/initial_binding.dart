import 'package:get/get.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../presentation/controllers/app_controller.dart';

/// Registers app-wide dependencies once, at startup.
///
/// Repositories are registered lazily ([Get.lazyPut]) so they are only
/// constructed (and only then touch Firebase) the first time a feature
/// actually asks for them — the app shell itself must be able to start
/// even before Firebase is configured for this environment.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppController(), permanent: true);
    Get.lazyPut<AuthRepository>(() => AuthRepositoryImpl());
  }
}
