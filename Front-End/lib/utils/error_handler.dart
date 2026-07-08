import 'package:dio/dio.dart';

/// Converts arbitrary thrown errors into a short, user-readable message.
/// Use at every UI surface that catches an exception — never put raw
/// DioException / SocketException strings in a snackbar.
///
/// The rules:
///   * Connection-class DioException → friendly "working offline" message.
///   * Bad-response DioException → "Request failed (404)" or similar.
///   * Anything else → trimmed `error.toString()` with the `Exception: `
///     prefix stripped and a length cap.
String friendlyErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Cannot connect to server. Working offline.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == null) return 'Server returned an error.';
        if (code >= 500) return 'Server error ($code). Try again shortly.';
        if (code == 401 || code == 403) return 'Not authorised.';
        if (code == 404) return 'Resource not found.';
        return 'Request failed ($code).';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badCertificate:
        return 'Server certificate is invalid.';
      case DioExceptionType.unknown:
        // `unknown` covers SocketException etc. — almost always offline.
        return 'Cannot connect to server. Working offline.';
      case DioExceptionType.transformTimeout:
        return 'Request timed out.';
    }
  }

  // Non-Dio errors — trim and cap.
  final msg = error.toString().replaceAll('Exception: ', '');
  if (msg.length > 200) return '${msg.substring(0, 200)}…';
  return msg;
}
