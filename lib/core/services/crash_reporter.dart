import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reporting facade. Mobile only; on web every call is a no-op.
abstract class CrashReporter {
  static CrashReporter instance = const NoopCrashReporter();

  Future<void> setUser(String? uid);
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal});
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> setUser(String? uid) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {}
}

/// One-way hash of the uid so reports never carry the raw identifier.
String hashedUserId(String uid) =>
    sha256.convert(utf8.encode(uid)).toString().substring(0, 24);

class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashlytics? get _crashlytics {
    if (kIsWeb) return null;
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseCrashlytics.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setUser(String? uid) async {
    try {
      await _crashlytics?.setUserIdentifier(
        uid == null ? '' : hashedUserId(uid),
      );
    } catch (_) {}
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    try {
      await _crashlytics?.recordError(error, stack, fatal: fatal);
    } catch (_) {}
  }
}
