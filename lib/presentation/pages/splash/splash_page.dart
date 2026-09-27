import 'package:flutter/material.dart';

import '../../widgets/app_loading_view.dart';

/// Initial route. Proves app bootstrap (theme, GetX, routing) works.
/// Navigation away from splash is driven entirely by [AuthController]
/// reacting to auth state — this page does not navigate itself.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLoadingView(message: 'OmniLife'));
  }
}
