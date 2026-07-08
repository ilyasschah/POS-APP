import 'package:dio/dio.dart';

/// Extracts a human-readable message from a DioException or any other error.
String parseApiError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data != null) {
      if (data is Map) {
        final msg = data['message'] ?? data['title'] ?? data['Message'];
        if (msg != null) return msg.toString();
      }
      if (data is String && !data.contains('<html') && data.length < 300) {
        return data;
      }
    }
    // Network / timeout errors
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Check your network.';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Is the API running?';
      default:
        return e.message ?? 'An unexpected network error occurred.';
    }
  }
  return e.toString();
}

/// Wraps a provider fetch and rethrows with a clean message.
/// Use inside FutureProvider bodies.
T rethrowApiError<T>(Object e, StackTrace st) {
  Error.throwWithStackTrace(
    Exception(parseApiError(e)),
    st,
  );
}
