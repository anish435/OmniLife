import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../widgets/app_loading_view.dart';

/// Initial route. Proves app bootstrap (theme, GetX, routing) works
/// before handing off to the dashboard shell. Once auth exists (Phase 4),
/// this is where the signed-in/signed-out redirect decision will live.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Get.offAllNamed(AppRoutes.dashboard);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLoadingView(message: 'OmniLife'));
  }
}
