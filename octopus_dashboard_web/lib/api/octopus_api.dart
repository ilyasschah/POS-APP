import 'package:dio/dio.dart';

import '../core/constants.dart';
import '../core/formatters.dart';
import '../core/json_utils.dart';
import '../models/dashboard.dart';
import '../models/document.dart';
import '../models/pos_session.dart';
import '../models/product.dart';
import '../models/stock.dart';
import '../models/user.dart';
import 'api_exception.dart';

/// Result of `POST /Auth/Login`.
class LoginResult {
  const LoginResult({required this.success, this.token, this.message});

  final bool success;
  final String? token;
  final String? message;
}

/// Typed client for the Octopus backend.
///
/// One instance per (baseUrl, token) pair — rebuilt by `apiProvider` whenever
/// the session changes.
///
/// Endpoint naming is inconsistent server-side and deliberately mirrored
/// verbatim here: `Document` is singular while `DocumentItems` is plural, and
/// users list at `GetAllUsers` while everything else lists at `GetAll`.
/// These are not typos to "fix" — getting them wrong 404s.
class OctopusApi {
  OctopusApi({required String baseUrl, String? token, this.onTokenExpired})
    : _dio = Dio(
        BaseOptions(
          baseUrl: normalizeBaseUrl(baseUrl),
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );

  final Dio _dio;
  final void Function()? onTokenExpired;

  /// Trims stray whitespace and trailing slashes so a user-typed URL like
  /// `https://host/api/ ` still composes correctly.
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static const _companyQuery = {'companyId': AppConfig.companyId};

  // --- Auth ---------------------------------------------------------------

  /// `POST /Auth/Login` — the only unauthenticated call.
  ///
  /// `DeviceId` is sent as null so signing in here doesn't burn a POS device
  /// seat.
  Future<LoginResult> login({
    required String email,
    required String password,
    CancelToken? cancelToken,
  }) async {
    return _guard(() async {
      final response = await _dio.post<dynamic>(
        '/Auth/Login',
        data: {'Email': email, 'Password': password, 'DeviceId': null},
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is! Map) {
        return const LoginResult(
          success: false,
          message: 'Unexpected response from server.',
        );
      }
      final json = Map<String, dynamic>.from(data);
      // Accept either casing for the token, matching the iOS client.
      final token = asStringOrNull(json['token'] ?? json['Token']);
      final success = asBool(json['success'] ?? json['Success'], token != null);
      return LoginResult(
        success: success && token != null,
        token: token,
        message: asStringOrNull(json['message'] ?? json['Message']),
      );
    });
  }

  // --- Dashboard ----------------------------------------------------------

  Future<DashboardData> fetchDashboard({
    required DateTime startDate,
    required DateTime endDate,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Dashboard/GetDashboardData',
        queryParameters: {
          ..._companyQuery,
          'startDate': Fmt.apiDate(startDate),
          'endDate': Fmt.apiDate(endDate),
          // Sale timestamps are stored in UTC, so the server needs our offset
          // to bucket "Hourly Peak Times" by local hour. Without it a 19:30
          // local sale in UTC+1 is reported as 18h.
          'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        },
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map) {
        throw const ApiException('Unexpected dashboard response from server.');
      }
      return DashboardData.fromJson(Map<String, dynamic>.from(data));
    });
  }

  // --- Products -----------------------------------------------------------

  Future<List<Product>> fetchProducts({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Products/GetAll',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, Product.fromJson);
    });
  }

  /// `PATCH /Products/Update?companyId=...`
  ///
  /// PATCH, not PUT, and `companyId` rides in the query string rather than the
  /// body. The body carries the **whole** product record — the server rejects
  /// partial updates.
  Future<void> updateProductPricing({
    required Product product,
    required double price,
    required double cost,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      await _dio.patch<dynamic>(
        '/Products/Update',
        queryParameters: _companyQuery,
        data: product.toUpdateJson(newPrice: price, newCost: cost),
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );
    });
  }

  // --- Stock --------------------------------------------------------------

  Future<List<StockEntry>> fetchStocks({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Stocks/GetAllStocks',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, StockEntry.fromJson);
    });
  }

  // --- Documents ----------------------------------------------------------

  /// Note the **singular** `Document` segment.
  Future<List<SalesDocument>> fetchDocuments({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Document/GetAll',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, SalesDocument.fromJson);
    });
  }

  /// Note the **plural** `DocumentItems` segment.
  Future<List<DocumentLineItem>> fetchDocumentItems({
    required int documentId,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/DocumentItems/GetByDocumentId',
        queryParameters: {'documentId': documentId, ..._companyQuery},
        cancelToken: cancelToken,
      );
      return asList(response.data, DocumentLineItem.fromJson);
    });
  }

  // --- POS sessions -------------------------------------------------------

  /// `GET /PosSession/History?companyId=...&take=...`
  ///
  /// Newest first, every register. Read-only by design: this app never calls
  /// Open/ConfirmOpening/Close/ForceClose — a session is opened, counted and
  /// closed on the register that owns the drawer, and an owner closing one
  /// from a browser would strand a till mid-count.
  Future<List<PosSession>> fetchPosSessions({
    int take = 50,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/PosSession/History',
        queryParameters: {..._companyQuery, 'take': take},
        cancelToken: cancelToken,
      );
      return asList(response.data, PosSession.fromJson);
    });
  }

  /// `GET /PosSession/Summary?companyId=...&sessionId=...`
  ///
  /// One session's figures — takings, order count, cash arithmetic and the
  /// per-method rows. Computed server-side on every call, so a closed
  /// session's numbers here can legitimately differ from the frozen ones on
  /// the session row itself (that gap is late sales).
  ///
  /// Fetched per session rather than for the whole list: /History carries
  /// neither takings nor an order count, and each summary is several queries
  /// server-side.
  Future<PosSessionSummary> fetchPosSessionSummary({
    required int sessionId,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/PosSession/Summary',
        queryParameters: {..._companyQuery, 'sessionId': sessionId},
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map) {
        throw const ApiException('Unexpected session summary from server.');
      }
      return PosSessionSummary.fromJson(Map<String, dynamic>.from(data));
    });
  }

  // --- Users --------------------------------------------------------------

  /// Note: `GetAllUsers`, not `GetAll` — the one list endpoint that breaks the
  /// pattern.
  Future<List<StaffUser>> fetchUsers({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Users/GetAllUsers',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, StaffUser.fromJson);
    });
  }

  /// `PATCH /Users/AdminResetPassword?companyId=...`
  ///
  /// PATCH, not POST. Requires the caller's own JWT to carry the Admin role
  /// (`accessLevel == 0`); a Cashier token gets a 403. There is no
  /// server-generated reset — a real password must always be supplied.
  Future<void> adminResetPassword({
    required int userId,
    required String newPassword,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      await _dio.patch<dynamic>(
        '/Users/AdminResetPassword',
        queryParameters: _companyQuery,
        data: {'userId': userId, 'newPassword': newPassword},
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );
    });
  }

  // --- Plumbing -----------------------------------------------------------

  /// Normalizes every transport failure into an [ApiException].
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        onTokenExpired?.call();
      }
      throw ApiException.from(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Unexpected error: $error');
    }
  }

  void close() => _dio.close(force: true);
}
