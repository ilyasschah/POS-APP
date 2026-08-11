import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:pos_app/update/app_release.dart';

/// Where the updater looks for releases.
///
/// The repository is PUBLIC, so `/releases/latest` answers unauthenticated —
/// verified with a plain unauthenticated request, which is what makes this
/// possible at all. A private repo would need a token, and a token shipped
/// inside a desktop app is a published token; the fallback then would be a
/// manifest served by our own API, which terminals already authenticate against.
const String kGitHubLatestReleaseUrl =
    'https://api.github.com/repos/ilyasschah/POS-APP/releases/latest';

/// Checks for, downloads and launches application updates. Windows only.
///
/// Every method is safe to call when there is no update, no network, or no
/// permission — a POS must never be blocked, delayed or crashed by its updater.
class UpdateService {
  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Android cannot silently self-install, and there is no macOS/Linux build.
  /// Callers use this to hide the UI rather than offer something that cannot work.
  static bool get isSupported => Platform.isWindows;

  /// Fetches the latest published release, or null when there is nothing usable.
  ///
  /// ⚠️ Never throws. The updater runs on a timer and behind a button on a till;
  /// an offline venue, a rate-limited API or a malformed payload must all read
  /// as "no update right now".
  Future<AppRelease?> fetchLatest() async {
    try {
      final response = await _dio.get<dynamic>(
        kGitHubLatestReleaseUrl,
        options: Options(
          // GitHub asks for this; without it the API may answer differently.
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      );

      final data = response.data;
      final json = data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : (data as Map).cast<String, dynamic>();

      return AppRelease.fromGitHubJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Downloads the installer to a temp folder and verifies it.
  ///
  /// Returns the path to the verified file, or null on any failure.
  ///
  /// 🚨 The checksum is not optional. This downloads an executable and then runs
  /// it with the user's privileges; installing 41 MB of unverified bytes off the
  /// network is the single most dangerous thing this app does. If the release
  /// carries no `.sha256`, or the hash does not match, the file is deleted and
  /// the update is refused.
  Future<String?> downloadInstaller(
    AppRelease release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    File? target;
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, release.installerName);
      target = File(path);

      // A partial file from an interrupted attempt would otherwise fail the
      // checksum for a reason nobody can diagnose.
      if (await target.exists()) await target.delete();

      await _dio.download(
        release.installerUrl,
        path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );

      final expected = await _fetchExpectedChecksum(release);
      if (expected == null) {
        await _deleteQuietly(target);
        return null;
      }

      final actual = await _sha256OfFile(target);
      if (actual != expected) {
        await _deleteQuietly(target);
        return null;
      }

      return path;
    } catch (_) {
      if (target != null) await _deleteQuietly(target);
      return null;
    }
  }

  /// Reads the `.sha256` sidecar published beside the installer.
  ///
  /// Format is `<hex>  <filename>`, as produced by the release workflow.
  Future<String?> _fetchExpectedChecksum(AppRelease release) async {
    final url = release.checksumUrl;
    if (url == null) return null;

    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return parseChecksumFile(response.data);
    } catch (_) {
      return null;
    }
  }

  /// Pulls the hex digest out of a `sha256sum`-style line. Public for testing.
  static String? parseChecksumFile(String? contents) {
    if (contents == null) return null;
    final match = RegExp(r'\b([a-fA-F0-9]{64})\b').firstMatch(contents);
    return match?.group(1)?.toLowerCase();
  }

  /// Streams the file through SHA-256 rather than reading it into memory —
  /// the installer is ~41 MB and a till may be a low-spec box.
  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover temp file is not worth surfacing.
    }
  }

  /// Starts the installer and returns true if it launched.
  ///
  /// The app must exit immediately afterwards: Windows cannot replace
  /// `pos_app.exe` while it is running, which is precisely what `AppMutex` in
  /// octopus_setup.iss detects. `/CLOSEAPPLICATIONS` lets Inno ask, and
  /// `/RESTARTAPPLICATIONS` brings the POS back up afterwards.
  ///
  /// ⚠️ Installs into Program Files, so this raises a UAC prompt. An operator
  /// without local admin rights cannot complete it — a deliberate trade-off
  /// (option A), not an oversight.
  Future<bool> launchInstaller(String installerPath) async {
    if (!isSupported) return false;
    try {
      await Process.start(
        installerPath,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS', '/NORESTART'],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
