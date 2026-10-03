import 'package:flutter/material.dart';

import '../../widgets/auth/auth_toggle.dart';
import 'login_page.dart';

/// Registration screen route entrypoint.
///
/// Shares the unified premium animated authentication experience with [LoginPage],
/// initialized in [AuthMode.signUp] mode.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginPage(initialMode: AuthMode.signUp);
  }
}
