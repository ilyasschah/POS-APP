/// Pure model + comparison logic for the in-app updater.
///
/// Deliberately free of Dio, Riverpod and dart:io so every rule below is unit
/// testable without a network or a filesystem — the parts that decide whether to
/// replace the software running a till are exactly the parts that must be pinned.
library;

/// A `major.minor.patch` version, with the ordering rules the updater needs.
///
/// ⚠️ String comparison is NOT good enough and is the classic bug here:
/// `'1.10.0' < '1.9.0'` lexically, so a terminal on 1.9.0 would never be offered
/// 1.10.0. Comparison must be numeric, per component.
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Accepts `1.2.3`, `v1.2.3` (git tag form) and `1.2.3+4` (pubspec form).
  ///
  /// The build number after `+` is deliberately IGNORED: releases are cut per
  /// version, the GitHub tag carries no build number, and comparing against one
  /// would make a terminal think it is out of date forever.
  static SemVer? tryParse(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.startsWith('v') || text.startsWith('V')) text = text.substring(1);
    text = text.split('+').first;

    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(text);
    if (match == null) return null;
    return SemVer(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is SemVer &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// A published release and the Windows installer attached to it.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.installerUrl,
    required this.installerName,
    required this.sizeBytes,
    this.checksumUrl,
    this.notes,
  });

  final SemVer version;
  final String installerUrl;
  final String installerName;
  final int sizeBytes;

  /// URL of the `.sha256` sidecar the release workflow publishes. Null means the
  /// download cannot be verified — see [UpdateService] for why that blocks.
  final String? checksumUrl;

  final String? notes;

  /// Builds a release from the GitHub `/releases/latest` payload.
  ///
  /// Returns null — rather than throwing — when the payload cannot yield a
  /// usable Windows update. A malformed or asset-less release must read as
  /// "nothing to install", never as an error the operator has to interpret.
  static AppRelease? fromGitHubJson(Map<String, dynamic> json) {
    // A draft is not published; a prerelease is not for tills. GitHub's
    // /releases/latest already excludes both, but the field is checked anyway
    // because a caller may pass a specific release.
    if (json['draft'] == true || json['prerelease'] == true) return null;

    final version = SemVer.tryParse(json['tag_name'] as String?);
    if (version == null) return null;

    final assets = (json['assets'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    Map<String, dynamic>? installer;
    for (final asset in assets) {
      final name = (asset['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.exe')) {
        installer = asset;
        break;
      }
    }
    // A release with notes but no installer is normal during a failed build —
    // there is simply nothing to offer.
    if (installer == null) return null;

    final installerName = installer['name'] as String;
    String? checksumUrl;
    for (final asset in assets) {
      if ((asset['name'] as String?) == '$installerName.sha256') {
        checksumUrl = asset['browser_download_url'] as String?;
        break;
      }
    }

    final url = installer['browser_download_url'] as String?;
    if (url == null || url.isEmpty) return null;

    return AppRelease(
      version: version,
      installerUrl: url,
      installerName: installerName,
      sizeBytes: (installer['size'] as num?)?.toInt() ?? 0,
      checksumUrl: checksumUrl,
      notes: json['body'] as String?,
    );
  }

  /// True when this release is newer than what is running.
  ///
  /// Strictly greater, never "different": a terminal that somehow runs a build
  /// AHEAD of the published release (a hand-built .exe on a dev machine) must
  /// not be offered a downgrade — the local database may already have been
  /// migrated to a newer Drift schema, which an older build cannot read.
  bool isNewerThan(SemVer running) => version > running;
}

/// Everything the UI needs to know about a check, without knowing how it works.
sealed class UpdateStatus {
  const UpdateStatus();
}

class UpdateIdle extends UpdateStatus {
  const UpdateIdle();
}

class UpdateChecking extends UpdateStatus {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateStatus {
  const UpdateUpToDate(this.running);
  final SemVer running;
}

class UpdateAvailable extends UpdateStatus {
  const UpdateAvailable(this.release);
  final AppRelease release;
}

class UpdateDownloading extends UpdateStatus {
  const UpdateDownloading(this.release, this.receivedBytes, this.totalBytes);
  final AppRelease release;
  final int receivedBytes;
  final int totalBytes;

  /// 0.0–1.0, or null while the server has not declared a length.
  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;
}

/// Downloaded and verified; waiting for the operator to accept the restart.
class UpdateReadyToInstall extends UpdateStatus {
  const UpdateReadyToInstall(this.release, this.installerPath);
  final AppRelease release;
  final String installerPath;
}

class UpdateFailed extends UpdateStatus {
  const UpdateFailed(this.message);
  final String message;
}
