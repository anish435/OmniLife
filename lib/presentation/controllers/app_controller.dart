import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Application-level state, per docs/architecture.md §3 (GetX owns
/// theme/session/app-level concerns). Feature-specific state does not
/// belong here.
class AppController extends GetxController {
  final themeMode = ThemeMode.system.obs;

  void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }
}
