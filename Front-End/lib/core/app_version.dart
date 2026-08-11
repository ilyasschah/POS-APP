import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The version of the build that is actually running.
///
/// ⚠️ There is exactly ONE source of truth for this number: `version:` in
/// `pubspec.yaml`. Flutter stamps it into the platform bundle at build time (on
/// Windows via `FLUTTER_VERSION` in `windows/runner/Runner.rc`), and
/// `PackageInfo` reads it back out — so what the app displays is necessarily what
/// was built, not a number someone remembered to update.
///
/// It used to be the string literal `'1.0.0'` in the About tab, which could not
/// disagree with the shipped build because it never changed at all. The installer
/// script had a third copy. Anything that compares versions — an updater above
/// all — is worthless built on that.
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});

  /// The `1.2.3` part of `version: 1.2.3+4`.
  final String version;

  /// The `4` part. Empty when pubspec declares no build number.
  final String buildNumber;

  /// What to show a human: `1.2.3` or `1.2.3+4`.
  String get display =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';
}

/// Reads the running build's version. Cached by Riverpod, and `PackageInfo`
/// caches internally too, so watching it from several screens costs one read.
final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion(version: info.version, buildNumber: info.buildNumber);
});
