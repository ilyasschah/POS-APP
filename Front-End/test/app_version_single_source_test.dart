// Pins that the app's version number is declared exactly ONCE, in pubspec.yaml.
//
// The bug this guards is the same shape as the one in
// `api_base_url_default_test.dart`, and it had already happened here: the
// version existed in THREE places that could not agree —
//   * `pubspec.yaml`            -> version: 1.0.0+1
//   * `octopus_setup.iss`       -> #define AppVersion "1.0.0"
//   * `settings_screen.dart`    -> versionLabel('1.0.0')   <- a string literal
//
// The third one is the dangerous one: it could not disagree with the shipped
// build because it never changed at all. Every release since would have shown
// "1.0.0" on screen regardless of what was installed.
//
// This matters far more than cosmetics. An in-app updater compares the running
// version against the latest release; built on a literal, it would either never
// offer an update or offer one forever.
//
// These are source-text assertions on purpose. There is no runtime seam that can
// catch a hardcoded literal — every value is individually valid, analyze is
// clean, and the app boots fine.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `version: 1.2.3+4` -> `1.2.3+4`
String _pubspecVersion() {
  final line = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('version:'));
  return line.split(':')[1].trim();
}

void main() {
  test('pubspec declares a parseable version', () {
    final version = _pubspecVersion();
    expect(
      RegExp(r'^\d+\.\d+\.\d+(\+\d+)?$').hasMatch(version),
      isTrue,
      reason: 'Got "$version". Flutter stamps this into the Windows exe and the '
          'installer reads it; an exotic value breaks both.',
    );
  });

  test('the About tab does not hardcode a version literal', () {
    final source =
        File('lib/settings/settings_screen.dart').readAsStringSync();

    // Matches versionLabel('1.0.0') / versionLabel("2.3") — i.e. a literal
    // passed straight in, rather than a value read from the running build.
    final hardcoded = RegExp(r'''versionLabel\(\s*['"][\d.]''');
    expect(
      hardcoded.hasMatch(source),
      isFalse,
      reason: 'The version must come from appVersionProvider '
          '(lib/core/app_version.dart), which reads what was actually built.',
    );
  });

  test('the installer script takes its version from outside, not a #define', () {
    final iss = File('octopus_setup.iss').readAsStringSync();

    // A bare `#define AppVersion "1.2.3"` would pin the installer to a number
    // that drifts from pubspec. The only permitted definition is the guarded
    // fallback, which exists so the script still compiles by hand.
    final unguarded = RegExp(r'^\s*#define\s+AppVersion\s', multiLine: true)
        .allMatches(iss)
        .length;
    expect(unguarded, 1,
        reason: 'Expected exactly one #define AppVersion, inside #ifndef.');
    expect(iss.contains('#ifndef AppVersion'), isTrue,
        reason: 'The definition must be guarded so /DAppVersion= overrides it.');

    // VersionInfoVersion rejects anything non-numeric at COMPILE time, so a
    // fallback like "0.0.0-dev" would break a hand build outright.
    final fallback =
        RegExp(r'#define\s+AppVersion\s+"([^"]+)"').firstMatch(iss)!.group(1)!;
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(fallback), isTrue,
        reason: 'Fallback "$fallback" must be numeric major.minor.patch.');
  });

  test('the installer keeps a fixed AppId so upgrades stay upgrades', () {
    final iss = File('octopus_setup.iss').readAsStringSync();

    // Without AppId, Inno falls back to AppName — so renaming the product turns
    // every future update into a SECOND parallel install with its own
    // Add/Remove Programs entry, instead of upgrading the one in the field.
    expect(RegExp(r'^\s*AppId=', multiLine: true).hasMatch(iss), isTrue);
  });
}
