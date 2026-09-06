/// Mutes `debugPrint` for the duration of one test.
///
/// ## Why these tests are loud
///
/// The sync tests point `SyncManager` at a fake adapter that answers **every**
/// request with 404, deliberately: a step that accidentally succeeded would do
/// real work and the assertion underneath it would stop meaning anything. But a
/// sync is ~40 steps, each one logs its own failure, and Dio's `toString()`
/// spends five lines explaining what a 404 is. One four-test file printed 619
/// lines, the great majority of it that explanation repeated 120 times.
///
/// The logging is correct — on a real till, one line per failed step is exactly
/// what you want when the server is down. It is the *fake* 404s that are not
/// worth reading, so they are silenced at the test, not at the source.
///
/// ## Using it
///
/// Call from `setUp` (or from a test body). `debugPrint` is a plain function
/// reference, so this swaps it and restores the original through `addTearDown` —
/// the next test file gets its output back either way, including when this one
/// fails.
///
/// 🚨 It hides `debugPrint` from the code under test too. When one of these
/// tests fails for a reason that is not obvious, comment the call out: the
/// step that broke is usually named in the flood.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void silenceDebugPrint() {
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  addTearDown(() => debugPrint = original);
}
