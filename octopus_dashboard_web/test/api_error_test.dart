import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_dashboard_web/api/api_exception.dart';
import 'package:octopus_dashboard_web/api/octopus_api.dart';
import 'package:octopus_dashboard_web/core/screen_state.dart';

DioException badResponse(Object? data, {int status = 400}) {
  final options = RequestOptions(path: '/Products/Update');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

void main() {
  group('ApiException', () {
    test('flags cancelled requests so they are never shown as errors', () {
      final error = ApiException.from(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.cancel,
        ),
      );
      expect(error.isCancelled, isTrue);
    });

    test('surfaces the server message in either casing', () {
      expect(
        ApiException.from(badResponse({'message': 'Out of stock'})).message,
        'Out of stock',
      );
      expect(
        ApiException.from(badResponse({'Message': 'Out of stock'})).message,
        'Out of stock',
      );
    });

    test('surfaces ASP.NET model-validation errors', () {
      final error = ApiException.from(
        badResponse({
          'errors': {
            'Name': ['The Name field is required.'],
          },
        }),
      );
      expect(error.message, 'The Name field is required.');
    });

    test('never dumps an HTML error page into the UI', () {
      final error = ApiException.from(
        badResponse('<!DOCTYPE html><html>...', status: 500),
      );
      expect(error.message, isNot(contains('DOCTYPE')));
      expect(error.message, contains('500'));
    });

    test('maps status codes to actionable messages', () {
      expect(ApiException.from(badResponse(null, status: 401)).isUnauthorized,
          isTrue);
      expect(
        ApiException.from(badResponse(null, status: 403)).isForbidden,
        isTrue,
      );
      expect(
        ApiException.from(badResponse(null, status: 404)).message,
        contains('404'),
      );
    });

    test('explains an unreachable host rather than leaking Dio internals', () {
      final error = ApiException.from(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(error.message, contains('Could not reach the server'));
    });
  });

  group('Base URL normalization', () {
    test('trims whitespace and trailing slashes', () {
      expect(
        OctopusApi.normalizeBaseUrl('  https://51-91-6-6.sslip.io/api/  '),
        'https://51-91-6-6.sslip.io/api',
      );
      expect(
        OctopusApi.normalizeBaseUrl('https://host/api'),
        'https://host/api',
      );
    });
  });

  group('ScreenState', () {
    test('starts in loading, not empty', () {
      const state = ScreenState<List<int>>.loading();
      expect(state.isInitialLoading, isTrue);
      expect(state.hasData, isFalse);
    });

    test('refreshing keeps existing data visible', () {
      const loaded = ScreenState<List<int>>.data([1, 2, 3]);
      final refreshing = loaded.toRefreshing();
      expect(refreshing.isRefreshing, isTrue);
      expect(refreshing.data, [1, 2, 3]);
      expect(refreshing.isInitialLoading, isFalse);
    });

    test('refreshing with no data falls back to a full spinner', () {
      const empty = ScreenState<List<int>>.loading();
      expect(empty.toRefreshing().isInitialLoading, isTrue);
    });

    test('a failed refresh preserves the data already on screen', () {
      const loaded = ScreenState<List<int>>.data([1, 2, 3]);
      final failed = loaded.toError('Server unreachable');
      expect(failed.hasError, isTrue);
      expect(failed.hasData, isTrue);
      expect(failed.data, [1, 2, 3]);
    });

    test('a first-load failure has no data to show', () {
      const initial = ScreenState<List<int>>.loading();
      final failed = initial.toError('Server unreachable');
      expect(failed.hasError, isTrue);
      expect(failed.hasData, isFalse);
    });
  });
}
