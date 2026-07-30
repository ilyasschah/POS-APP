import 'package:dio/dio.dart';

/// A normalized API failure.
///
/// Every Dio error is funneled through [ApiException.from] so screens never
/// have to reason about `DioExceptionType` themselves — in particular the
/// [isCancelled] case, which must never be shown to the user as an error.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isCancelled = false});

  final String message;
  final int? statusCode;

  /// True when the request was cancelled because the user navigated away
  /// mid-flight. This is normal control flow, not a failure.
  final bool isCancelled;

  /// The caller's token lacks the required role (the server enforces a
  /// `ManagerOnly` policy on admin actions).
  bool get isForbidden => statusCode == 403;

  /// The session's JWT is missing, expired or rejected.
  bool get isUnauthorized => statusCode == 401;

  factory ApiException.from(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const ApiException('Request cancelled', isCancelled: true);
    }

    final status = error.response?.statusCode;
    final serverMessage = _extractMessage(error.response?.data);
    if (serverMessage != null) {
      return ApiException(serverMessage, statusCode: status);
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The server took too long to respond. Check your connection and try again.',
      DioExceptionType.badCertificate =>
        "The server's security certificate could not be verified.",
      DioExceptionType.connectionError =>
        'Could not reach the server. Check the API Base URL and your connection.',
      DioExceptionType.badResponse => switch (status) {
        401 => 'Your session has expired. Please sign in again.',
        403 => "You don't have permission to do that.",
        404 => 'That endpoint was not found on the server (404).',
        _ => 'The server returned an error${status == null ? '' : ' ($status)'}.',
      },
      _ => 'Something went wrong. Please try again.',
    };

    return ApiException(message, statusCode: status);
  }

  /// Pulls the human-readable message out of a `400 Bad Request` body.
  ///
  /// The backend's business-logic failures carry a `message` field, but the
  /// casing is inconsistent — check both.
  static String? _extractMessage(Object? data) {
    if (data is Map) {
      for (final key in const ['message', 'Message', 'title', 'error']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      // ASP.NET model-validation shape: { errors: { Field: ["msg"] } }
      final errors = data['errors'] ?? data['Errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            final first = value.first;
            if (first is String && first.trim().isNotEmpty) return first.trim();
          }
        }
      }
    }
    if (data is String) {
      final trimmed = data.trim();
      // Guard against dumping an HTML error page into the UI.
      if (trimmed.isNotEmpty &&
          trimmed.length <= 300 &&
          !trimmed.startsWith('<')) {
        return trimmed;
      }
    }
    return null;
  }

  @override
  String toString() => message;
}
