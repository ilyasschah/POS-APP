import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';

/// Pings the C# API every 15 seconds and emits `true` if it's reachable.
///
/// "Reachable" means we got *any* HTTP response — including 4xx — because a
/// running server that rejects our specific request is still online. Only
/// connection errors / timeouts count as "offline."
///
/// The first emission fires immediately so the sidebar doesn't show a stale
/// state for 15 seconds after launch. Errors are caught and yielded as
/// `false`; the stream never breaks.
final serverStatusProvider = StreamProvider<bool>((ref) async* {
  final dio = createDio();
  // Shorter timeouts than the app-wide defaults — we don't want the sidebar
  // indicator to stall a check for 10s when the network is clearly dead.
  final pingOptions = Options(
    sendTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  );

  int companyId() => ref.read(selectedCompanyProvider)?.id ?? 1;

  // First check fires immediately.
  yield await _ping(dio, pingOptions, companyId());

  // Then every 15 seconds for the lifetime of the provider.
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
    yield await _ping(dio, pingOptions, companyId());
  }
});

Future<bool> _ping(Dio dio, Options options, int companyId) async {
  try {
    // Hit a lightweight endpoint. /Currencies/GetAll is small (single-digit
    // rows typically) and exists on every deployment. Any 2xx OR 4xx means
    // the server is alive; only connection-class failures mean offline.
    await dio.get<dynamic>(
      '/Currencies/GetAll',
      queryParameters: {'companyId': companyId},
      options: options,
    );
    return true;
  } on DioException catch (e) {
    // A response (even an error one) means the server is up and reachable.
    if (e.type == DioExceptionType.badResponse) return true;
    return false;
  } catch (_) {
    return false;
  }
}
