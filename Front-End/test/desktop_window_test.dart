// Pins the full-screen button's memory: the choice is saved on this device and
// the next launch reopens the same way. And the Windows quirk that came with it
// — a MAXIMIZED window ignores full screen, so it is unmaximized first and put
// back on exit.
//
// The native window is faked at the `window_manager` method channel, so this is
// the real code path down to the platform call.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/desktop_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in for the native window, recording what it was asked to do.
class _FakeWindow {
  bool fullScreen = false;
  bool maximized = false;
  final calls = <String>[];

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'isFullScreen':
        calls.add('isFullScreen');
        return fullScreen;
      case 'isMaximized':
        calls.add('isMaximized');
        return maximized;
      case 'setFullScreen':
        fullScreen = (call.arguments as Map)['isFullScreen'] as bool;
        calls.add('setFullScreen($fullScreen)');
        return null;
      case 'maximize':
        maximized = true;
        calls.add('maximize');
        return null;
      case 'unmaximize':
        maximized = false;
        calls.add('unmaximize');
        return null;
    }
    calls.add(call.method);
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  late _FakeWindow window;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    window = _FakeWindow();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, window.handle);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<bool?> remembered() async =>
      (await SharedPreferences.getInstance()).getBool(kFullScreenPrefKey);

  test('going full screen is remembered for the next launch', () async {
    await toggleDesktopFullScreen();

    expect(window.fullScreen, isTrue);
    expect(await remembered(), isTrue);
  });

  test('leaving full screen is remembered too', () async {
    window.fullScreen = true;

    await toggleDesktopFullScreen();

    expect(window.fullScreen, isFalse);
    expect(await remembered(), isFalse);
  });

  test('a launch after full screen reopens full screen', () async {
    SharedPreferences.setMockInitialValues({kFullScreenPrefKey: true});

    await restoreDesktopFullScreen(await SharedPreferences.getInstance());

    expect(window.fullScreen, isTrue);
  });

  test('a launch with full screen off, or never set, leaves the window alone',
      () async {
    SharedPreferences.setMockInitialValues({kFullScreenPrefKey: false});
    await restoreDesktopFullScreen(await SharedPreferences.getInstance());
    SharedPreferences.setMockInitialValues({});
    await restoreDesktopFullScreen(await SharedPreferences.getInstance());

    expect(window.calls, isEmpty);
    expect(window.fullScreen, isFalse);
  });

  test('Windows: a maximized window is unmaximized first and re-maximized on exit',
      () async {
    window.maximized = true;

    await toggleDesktopFullScreen();
    expect(window.calls,
        ['isFullScreen', 'isMaximized', 'unmaximize', 'setFullScreen(true)']);

    window.calls.clear();
    await toggleDesktopFullScreen();
    expect(window.calls, ['isFullScreen', 'setFullScreen(false)', 'maximize']);
    expect(window.maximized, isTrue);
  });

  test('not a desktop (the Android tablets): nothing is touched', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await toggleDesktopFullScreen();
    await restoreDesktopFullScreen(await SharedPreferences.getInstance());

    expect(window.calls, isEmpty);
    expect(await remembered(), isNull);
  });
}
