// The in-app updater's decision logic: which release is newer, what a GitHub
// payload actually offers, and when installing would lose the operator's work.
//
// These are the parts that replace the software running a till, so they are
// pinned without a network or a filesystem in the way.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/update/app_release.dart';
import 'package:pos_app/update/update_guard.dart';
import 'package:pos_app/update/update_service.dart';

Map<String, dynamic> _release({
  String tag = 'v1.2.0',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>>? assets,
}) =>
    {
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'body': 'notes',
      'assets': assets ??
          [
            {
              'name': 'Octopus_POS_Setup_v1.2.0.exe',
              'size': 43000000,
              'browser_download_url':
                  'https://github.com/o/r/releases/download/v1.2.0/Octopus_POS_Setup_v1.2.0.exe',
            },
            {
              'name': 'Octopus_POS_Setup_v1.2.0.exe.sha256',
              'size': 80,
              'browser_download_url':
                  'https://github.com/o/r/releases/download/v1.2.0/Octopus_POS_Setup_v1.2.0.exe.sha256',
            },
          ],
    };

void main() {
  group('SemVer', () {
    test('parses the three forms the pipeline actually produces', () {
      expect(SemVer.tryParse('1.2.3'), const SemVer(1, 2, 3)); // manifest
      expect(SemVer.tryParse('v1.2.3'), const SemVer(1, 2, 3)); // git tag
      expect(SemVer.tryParse('1.2.3+4'), const SemVer(1, 2, 3)); // pubspec
    });

    test('rejects anything it cannot order', () {
      for (final bad in ['', '1.2', 'x.y.z', '1.2.3-beta', null]) {
        expect(SemVer.tryParse(bad), isNull, reason: 'should reject "$bad"');
      }
    });

    test('orders NUMERICALLY, not as text', () {
      // The classic updater bug: lexically '1.10.0' < '1.9.0', so a terminal on
      // 1.9.0 would never be offered 1.10.0 and would sit stale forever.
      expect(SemVer.tryParse('1.10.0')! > SemVer.tryParse('1.9.0')!, isTrue);
      expect(SemVer.tryParse('2.0.0')! > SemVer.tryParse('1.99.99')!, isTrue);
      expect(SemVer.tryParse('1.0.10')! > SemVer.tryParse('1.0.9')!, isTrue);
    });
  });

  group('AppRelease.fromGitHubJson', () {
    test('reads the installer and its checksum sidecar', () {
      final release = AppRelease.fromGitHubJson(_release())!;

      expect(release.version, const SemVer(1, 2, 0));
      expect(release.installerName, 'Octopus_POS_Setup_v1.2.0.exe');
      expect(release.installerUrl, endsWith('.exe'));
      expect(release.checksumUrl, endsWith('.exe.sha256'));
      expect(release.sizeBytes, 43000000);
    });

    test('offers nothing when the release has no installer', () {
      // A build that failed after tagging leaves notes and no asset. That must
      // read as "no update", not as an error on the operator's screen.
      final release = AppRelease.fromGitHubJson(_release(assets: []));
      expect(release, isNull);
    });

    test('ignores drafts and prereleases', () {
      expect(AppRelease.fromGitHubJson(_release(draft: true)), isNull);
      expect(AppRelease.fromGitHubJson(_release(prerelease: true)), isNull);
    });

    test('survives a payload that is not a release at all', () {
      // e.g. GitHub's rate-limit body: {"message": "...", "documentation_url": ...}
      expect(AppRelease.fromGitHubJson({'message': 'API rate limit exceeded'}),
          isNull);
    });

    test('a release with an exe but NO checksum still parses, url null', () {
      final json = _release(assets: [
        {
          'name': 'Octopus_POS_Setup_v1.2.0.exe',
          'size': 1,
          'browser_download_url': 'https://example.invalid/x.exe',
        },
      ]);
      final release = AppRelease.fromGitHubJson(json)!;
      // Parsing succeeds; UpdateService is what refuses to install it unverified.
      expect(release.checksumUrl, isNull);
    });
  });

  group('against the REAL GitHub payload', () {
    // Captured from https://api.github.com/repos/ilyasschah/POS-APP/releases/latest
    // after the first successful pipeline run. Hand-built fixtures only prove the
    // parser matches the shape I imagined; this proves it matches the shape
    // GitHub actually sends.
    Map<String, dynamic> realPayload() => jsonDecode(
          File('test/fixtures/github_release_latest.json').readAsStringSync(),
        ) as Map<String, dynamic>;

    test('yields a usable release', () {
      final release = AppRelease.fromGitHubJson(realPayload())!;

      expect(release.version, const SemVer(1, 0, 1));
      expect(release.installerName, endsWith('.exe'));
      expect(release.installerUrl, startsWith('https://'));
      expect(release.sizeBytes, greaterThan(1000000)); // a real installer
      expect(release.checksumUrl, endsWith('.exe.sha256'),
          reason: 'the pipeline must keep publishing the checksum sidecar — '
              'without it UpdateService refuses to install');
    });

    test('the installer asset is picked, never the checksum file', () {
      // Both assets start with the same name; matching loosely would hand the
      // 80-byte .sha256 to the installer launcher.
      final release = AppRelease.fromGitHubJson(realPayload())!;
      expect(release.installerUrl, isNot(endsWith('.sha256')));
    });

    test('a terminal on the shipped version is told it is up to date', () {
      final release = AppRelease.fromGitHubJson(realPayload())!;
      expect(release.isNewerThan(const SemVer(1, 0, 1)), isFalse);
      expect(release.isNewerThan(const SemVer(1, 0, 0)), isTrue);
    });
  });

  group('isNewerThan', () {
    test('offers a strictly higher version', () {
      final release = AppRelease.fromGitHubJson(_release())!;
      expect(release.isNewerThan(const SemVer(1, 1, 9)), isTrue);
    });

    test('does not offer the version already running', () {
      final release = AppRelease.fromGitHubJson(_release())!;
      expect(release.isNewerThan(const SemVer(1, 2, 0)), isFalse);
    });

    test('never offers a DOWNGRADE', () {
      // A dev box running a hand-built 1.3.0 must not be pushed back to 1.2.0:
      // its local Drift database may already be migrated to a newer schema that
      // the older build cannot read.
      final release = AppRelease.fromGitHubJson(_release())!;
      expect(release.isNewerThan(const SemVer(1, 3, 0)), isFalse);
    });
  });

  group('checksum parsing', () {
    test('reads the hex digest out of a sha256sum-style line', () {
      const hash =
          '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';
      expect(
        UpdateService.parseChecksumFile('$hash  Octopus_POS_Setup_v1.2.0.exe\n'),
        hash,
      );
    });

    test('normalises case, so an uppercase digest still matches', () {
      const upper =
          '9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08';
      expect(UpdateService.parseChecksumFile(upper), upper.toLowerCase());
    });

    test('returns null for anything that is not a digest', () {
      // A 404 HTML page must not be mistaken for a checksum — that would make
      // verification pass against garbage.
      for (final bad in [null, '', 'not a hash', '<html>404</html>', 'abc123']) {
        expect(UpdateService.parseChecksumFile(bad), isNull,
            reason: 'should reject "$bad"');
      }
    });
  });

  group('pre-install guard', () {
    test('a clean terminal has nothing in the way', () {
      final blockers =
          evaluateUpdateBlockers(cartItemCount: 0, pendingPushCount: 0);
      expect(blockers, isEmpty);
      expect(canInstallUpdate(blockers), isTrue);
    });

    test('a cart with items BLOCKS the install', () {
      // The live cart is memory-only until checkout, so restarting loses it.
      final blockers =
          evaluateUpdateBlockers(cartItemCount: 3, pendingPushCount: 0);
      expect(blockers, contains(UpdateBlocker.activeCart));
      expect(canInstallUpdate(blockers), isFalse);
    });

    test('unsynced rows warn but do NOT block', () {
      // They are on disk and the new build reads the same database, so blocking
      // here would strand a terminal that is merely offline.
      final blockers =
          evaluateUpdateBlockers(cartItemCount: 0, pendingPushCount: 7);
      expect(blockers, [UpdateBlocker.unsyncedWork]);
      expect(canInstallUpdate(blockers), isTrue);
    });

    test('the fatal blocker is reported first when both apply', () {
      final blockers =
          evaluateUpdateBlockers(cartItemCount: 2, pendingPushCount: 5);
      expect(blockers.first, UpdateBlocker.activeCart);
      expect(canInstallUpdate(blockers), isFalse);
    });
  });
}
