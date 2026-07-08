import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/utils/error_handler.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('returns a friendly message for transform timeout errors', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.transformTimeout,
      );

      expect(friendlyErrorMessage(error), 'Request timed out.');
    });
  });
}
