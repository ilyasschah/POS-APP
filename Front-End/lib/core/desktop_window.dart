import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// This terminal's full-screen choice, remembered ON THE DEVICE.
///
/// SharedPreferences, never the cloud-synced app properties: whether the till
/// runs full screen is a property of this monitor, and a cashier going full
/// screen on one POS must not change another sharing the company.
const kFullScreenPrefKey = 'ui.fullScreen';

/// window_manager exists only on desktop; Android and web have no window.
bool get isDesktopWindow =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Windows only: whether the window was maximized before it went full screen,
/// so leaving full screen puts it back the way the cashier had it.
bool _wasMaximizedBeforeFullScreen = false;

/// Puts the window in or out of full screen.
///
/// 🚨 Windows only: window_manager enters full screen by moving and resizing
/// the window to the monitor rect, and Windows ignores that on a MAXIMIZED
/// (zoomed) window — it keeps the maximized placement, so the button did
/// nothing at all on a till that boots maximized. macOS uses the native
/// full-screen path and was never affected. Drop out of maximized first, and
/// put it back on exit.
Future<void> setDesktopFullScreen(bool full) async {
  if (!isDesktopWindow) return;
  if (defaultTargetPlatform == TargetPlatform.windows) {
    if (full) {
      _wasMaximizedBeforeFullScreen = await windowManager.isMaximized();
      if (_wasMaximizedBeforeFullScreen) await windowManager.unmaximize();
    }
    await windowManager.setFullScreen(full);
    if (!full && _wasMaximizedBeforeFullScreen) {
      await windowManager.maximize();
      _wasMaximizedBeforeFullScreen = false;
    }
    return;
  }
  await windowManager.setFullScreen(full);
}

/// The full-screen button: flips the window and REMEMBERS the choice, so the
/// next launch opens the same way.
///
/// Saved here, by the button, rather than from window_manager's full-screen
/// events: on Windows those only fire for a maximize-sized transition, which
/// its own full-screen path does not produce.
Future<void> toggleDesktopFullScreen() async {
  if (!isDesktopWindow) return;
  final full = !await windowManager.isFullScreen();
  await setDesktopFullScreen(full);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kFullScreenPrefKey, full);
}

/// At launch: back to full screen if this terminal was left that way.
///
/// Call once the window exists (after the first frame). Never throws — a
/// window that will not go full screen must not stop the POS from starting.
Future<void> restoreDesktopFullScreen(SharedPreferences prefs) async {
  if (!isDesktopWindow) return;
  if (prefs.getBool(kFullScreenPrefKey) != true) return;
  try {
    if (await windowManager.isFullScreen()) return;
    await setDesktopFullScreen(true);
  } catch (e) {
    debugPrint('Could not restore full screen: $e');
  }
}
