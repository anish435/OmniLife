import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stack_trace/stack_trace.dart';

/// Lets Flutter print errors that carry package:stack_trace chains (raised
/// from code run inside `tester.runAsync`) instead of crashing the reporter
/// with a stack-frame assertion, which hid the real failure and made a
/// couple of tests fail at random.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  FlutterError.demangleStackTrace = (StackTrace stack) {
    if (stack is Trace) return stack.vmTrace;
    if (stack is Chain) return stack.toTrace().vmTrace;
    return stack;
  };
  // Controllers read device storage when they start; without a mock that
  // raised MissingPluginException after a test had already finished.
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
