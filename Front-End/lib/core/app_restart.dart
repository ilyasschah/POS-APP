import 'dart:io';

import 'package:flutter/foundation.dart';

/// Relaunching the app after an operation that can only complete on a fresh
/// boot — a database restore (the file cannot be swapped while Drift holds it
/// open) or a company-wide reset.
class AppRestart {
  AppRestart._();

  /// True where the process can actually relaunch itself.
  ///
  /// Android and iOS deliberately give an app no supported way to start itself
  /// again after `exit()`, so calling [restart] there would simply close the
  /// till with no way back. Callers use this to show "close and reopen the app"
  /// instead of a countdown that ends in the app vanishing.
  static bool get canRestart =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Spawns a detached copy of this executable and exits.
  ///
  /// Returns false if the relaunch could not be started — a locked executable,
  /// or a platform that cannot do it — in which case the caller must tell the
  /// operator to restart manually. Never returns true: on success the process
  /// is already gone.
  static Future<bool> restart() async {
    if (!canRestart) return false;
    try {
      await Process.start(
        Platform.resolvedExecutable,
        <String>[],
        workingDirectory: File(Platform.resolvedExecutable).parent.path,
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (e) {
      debugPrint('AppRestart: could not relaunch — $e');
      return false;
    }
  }
}
