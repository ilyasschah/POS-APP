import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show FileImage;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes product images to disk and returns the absolute local path so we
/// can store *paths* in SQLite instead of binary blobs (plan constraint).
///
/// Accepts either a remote URL (`http://...` / `https://...`) or a raw base64
/// string — the existing C# `/Products/GetAll` endpoint currently serves
/// base64-encoded bytes, but the helper is URL-ready for when the backend
/// switches to a CDN.
class ImageSyncHelper {
  ImageSyncHelper(this._dio);

  final Dio _dio;

  static const _defaultFolder = 'product_images';

  /// Returns the absolute path of the saved file, or `null` if the source
  /// was empty/invalid or any step failed. **Never throws** — a single bad
  /// image must not break the master-data pull.
  ///
  /// Failures are logged via [debugPrint] so they surface in `flutter run`
  /// output. Common culprits worth scanning the logs for:
  ///   * `FormatException` — the server sent malformed base64
  ///   * `FileSystemException` — permission / disk-full / path-too-long
  ///   * `DioException` — URL-mode download failed
  ///
  /// `folder` controls the subdirectory under the app documents dir. Default
  /// is `product_images`. Pass `company_logos` from the company pull so logos
  /// don't get mixed in with the product cache.
  Future<String?> downloadAndSaveImage(
    String? imageUrlOrBase64,
    int productId, {
    String folder = _defaultFolder,
  }) async {
    // Null/empty source isn't a failure — products without images are
    // legitimate. Don't log; just return.
    if (imageUrlOrBase64 == null || imageUrlOrBase64.isEmpty) return null;

    try {
      final bytes = await _resolveBytes(imageUrlOrBase64);
      if (bytes == null || bytes.isEmpty) {
        debugPrint(
            'ImageSyncHelper: empty bytes after decode for id=$productId');
        return null;
      }

      final dir = await _ensureImagesDir(folder);
      final file = File(p.join(dir.path, '$productId.jpg'));
      await file.writeAsBytes(bytes, flush: true);
      // The file content just changed under a reused path. Flutter's ImageCache
      // keys FileImage by path, so evict the stale entry — otherwise the UI
      // keeps showing the previous (old) image after a sync overwrite.
      await FileImage(file).evict();
      return file.path;
    } catch (e) {
      debugPrint('Failed to save image for ID $productId: $e');
      return null;
    }
  }

  Future<void> deleteImage(int productId,
      {String folder = _defaultFolder}) async {
    try {
      final dir = await _ensureImagesDir(folder);
      final file = File(p.join(dir.path, '$productId.jpg'));
      await FileImage(file).evict();
      if (await file.exists()) await file.delete();
    } catch (e) {
      // best-effort cleanup; surface to logs but don't throw.
      debugPrint('Failed to delete image for ID $productId: $e');
    }
  }

  /// Use from the UI when binding a Drift row to an Image widget — returns
  /// `null` if the file is gone (app reinstall, cache wipe, etc.) so the
  /// caller can fall back to a placeholder.
  String? resolveExisting(String? localPath) {
    if (localPath == null || localPath.isEmpty) return null;
    return File(localPath).existsSync() ? localPath : null;
  }

  Future<Uint8List?> _resolveBytes(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final res = await _dio.get<List<int>>(
        source,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      return data == null ? null : Uint8List.fromList(data);
    }
    // Treat anything else as base64. Strip a possible data-URI prefix.
    final cleaned = source.contains(',') ? source.split(',').last : source;
    return base64Decode(cleaned);
  }

  Future<Directory> _ensureImagesDir(String folder) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
