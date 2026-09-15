import 'package:dio/dio.dart';

import '../core/formatters.dart';
import '../core/json_utils.dart';
import '../models/dashboard.dart';
import '../models/document.dart';
import '../models/document_lookups.dart';
import '../models/pos_session.dart';
import '../models/product.dart';
import '../models/product_group.dart';
import '../models/stock.dart';
import '../models/stock_rule.dart';
import '../models/user.dart';
import 'api_exception.dart';

/// Result of `POST /Auth/Login`.
class LoginResult {
  const LoginResult({
    required this.success,
    this.token,
    this.message,
    this.companyId,
    this.userId,
  });

  final bool success;
  final String? token;
  final String? message;

  /// The company the signed-in user belongs to, from `user.companyId` in the
  /// login response.
  ///
  /// 🚨 This is what scopes every subsequent request. It used to be the
  /// compile-time constant `AppConfig.companyId` (25), so whoever signed in,
  /// the dashboard reported company 25's sales — and a newly created company
  /// looked like it had "no access" when in fact it was never being asked
  /// about.
  final int? companyId;

  final int? userId;
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
  OctopusApi({
    required String baseUrl,
    String? token,
    this.companyId,
    this.onTokenExpired,
  }) : _dio = Dio(
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

  /// The tenant every request is scoped to — the signed-in user's own company,
  /// carried from the login response. Null only before sign-in, when the sole
  /// legal call is [login] itself.
  final int? companyId;

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

  /// `companyId` for the query string of every scoped call.
  ///
  /// Throws rather than falling back to a default: a request that quietly went
  /// out under the wrong tenant is how this app showed one company's figures to
  /// another, and a hard failure here is a bug report instead of a silent lie.
  Map<String, dynamic> get _companyQuery {
    final id = companyId;
    if (id == null || id <= 0) {
      throw const ApiException(
        'Not signed in to a company. Sign in again.',
      );
    }
    return {'companyId': id};
  }

  static final Options _json = Options(contentType: Headers.jsonContentType);

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
        options: _json,
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

      // `user.companyId` is the tenant this session may see. Same either-casing
      // tolerance as the token: the server serialises PascalCase today, and the
      // client should not break the day that changes.
      final rawUser = json['user'] ?? json['User'];
      final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
      int? asIntOrNull(dynamic v) => v is num ? v.toInt() : null;

      return LoginResult(
        success: success && token != null,
        token: token,
        message: asStringOrNull(json['message'] ?? json['Message']),
        companyId: asIntOrNull(user?['companyId'] ?? user?['CompanyId']),
        userId: asIntOrNull(user?['id'] ?? user?['Id']),
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

  Future<List<ProductGroup>> fetchProductGroups({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/ProductGroups/GetAll',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, ProductGroup.fromJson);
    });
  }

  Future<void> createProductGroup({
    required String name,
    required int? parentGroupId,
    required String color,
    required int rank,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      await _dio.post<dynamic>(
        '/ProductGroups/Add',
        queryParameters: _companyQuery,
        data: {
          'name': name.trim(),
          'parentGroupId': parentGroupId,
          'color': color,
          'rank': rank,
        },
        options: _json,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> updateProductGroup({
    required ProductGroup group,
    required String name,
    required int? parentGroupId,
    required String color,
    required int rank,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      await _dio.patch<dynamic>(
        '/ProductGroups/Update',
        queryParameters: _companyQuery,
        data: {
          'id': group.id,
          'name': name.trim(),
          'parentGroupId': parentGroupId,
          'color': color,
          'rank': rank,
        },
        options: _json,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> deleteProductGroup({required int id, CancelToken? cancelToken}) {
    return _guard(() async {
      await _dio.delete<dynamic>(
        '/ProductGroups/Delete',
        queryParameters: {'id': id, ..._companyQuery},
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> createProduct({
    required String name,
    required double price,
    required double cost,
    required int? productGroupId,
    required String color,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      await _dio.post<dynamic>(
        '/Products/Add',
        queryParameters: _companyQuery,
        data: Product(
          id: 0,
          name: name,
          code: null,
          price: price,
          cost: cost,
          isTaxInclusivePrice: false,
          isPriceChangeAllowed: true,
          isService: false,
          isUsingDefaultQuantity: true,
          isEnabled: true,
          color: color,
        ).toCreateJson(
          newName: name,
          newPrice: price,
          newCost: cost,
          newProductGroupId: productGroupId,
          newColor: color,
        ),
        options: _json,
        cancelToken: cancelToken,
      );
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
        options: _json,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> updateProduct({
    required Product product,
    required String name,
    required double price,
    required double cost,
    required int? productGroupId,
    required String color,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      await _dio.patch<dynamic>(
        '/Products/Update',
        queryParameters: _companyQuery,
        data: {
          ...product.toUpdateJson(newPrice: price, newCost: cost),
          'name': name.trim(),
          'productGroupId': productGroupId,
          'color': color.trim().isEmpty ? 'Transparent' : color.trim(),
        },
        options: _json,
        cancelToken: cancelToken,
      );
    });
  }

  Future<void> deleteProduct({required int id, CancelToken? cancelToken}) {
    return _guard(() async {
      await _dio.delete<dynamic>(
        '/Products/Delete',
        queryParameters: {'id': id, ..._companyQuery},
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

  /// `GET /StockControls/GetAll` — each product's stock rules: low-stock
  /// warning, reorder point, preferred quantity and supplier. A product nobody
  /// set rules for has no row.
  Future<List<StockRule>> fetchStockRules({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/StockControls/GetAll',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, StockRule.fromJson);
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

  /// `GET /DocumentType/GetAll` — global master data, no `companyId`.
  Future<List<DocumentTypeOption>> fetchDocumentTypes({
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/DocumentType/GetAll',
        cancelToken: cancelToken,
      );
      return asList(response.data, DocumentTypeOption.fromJson);
    });
  }

  /// `GET /Customer/GetAllCustomers` — customers and suppliers in one list.
  /// Singular `Customer`, and the action is not `GetAll`.
  Future<List<CustomerOption>> fetchCustomers({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Customer/GetAllCustomers',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, CustomerOption.fromJson);
    });
  }

  Future<List<WarehouseOption>> fetchWarehouses({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Warehouses/GetAll',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, WarehouseOption.fromJson);
    });
  }

  /// `GET /Taxes/GetAllTaxes` — the action is not `GetAll` here either.
  Future<List<TaxOption>> fetchTaxes({CancelToken? cancelToken}) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Taxes/GetAllTaxes',
        queryParameters: _companyQuery,
        cancelToken: cancelToken,
      );
      return asList(response.data, TaxOption.fromJson);
    });
  }

  /// `GET /Document/GetNextNumber` — `26-220-000001` for a Refund.
  ///
  /// 🚨 Not a peek: every call advances the server's counter for that type, so
  /// only ask when a number is actually going to be shown.
  Future<String> fetchNextDocumentNumber({
    required int documentTypeId,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/Document/GetNextNumber',
        queryParameters: {..._companyQuery, 'documentTypeId': documentTypeId},
        cancelToken: cancelToken,
      );
      final number = asString(response.data).trim();
      if (number.isEmpty) {
        throw const ApiException('The server did not return a document number.');
      }
      return number;
    });
  }

  /// `POST /Document/Add` — answers `{ message, data: { id } }`.
  Future<int> createDocument(Map<String, dynamic> body) {
    return _guard(() async {
      final response = await _dio.post<dynamic>(
        '/Document/Add',
        queryParameters: _companyQuery,
        data: body,
        options: _json,
      );
      return _createdId(response.data, 'document');
    });
  }

  /// `PATCH /Document/Update` — only the fields present change.
  Future<void> updateDocument(Map<String, dynamic> body) {
    return _guard(() async {
      await _dio.patch<dynamic>(
        '/Document/Update',
        queryParameters: _companyQuery,
        data: body,
        options: _json,
      );
    });
  }

  /// `DELETE /Document/Delete` — the server gives back the stock its lines
  /// moved, and its lines, taxes and payments go with it.
  Future<void> deleteDocument({required int id}) {
    return _guard(() async {
      await _dio.delete<dynamic>(
        '/Document/Delete',
        queryParameters: {'id': id, ..._companyQuery},
      );
    });
  }

  /// `POST /DocumentItems/Add` — this is what moves the line's stock.
  Future<int> addDocumentItem(Map<String, dynamic> body) {
    return _guard(() async {
      final response = await _dio.post<dynamic>(
        '/DocumentItems/Add',
        queryParameters: _companyQuery,
        data: body,
        options: _json,
      );
      return _createdId(response.data, 'line');
    });
  }

  /// `PATCH /DocumentItems/Update` — moves only the difference in stock.
  Future<void> updateDocumentItem(Map<String, dynamic> body) {
    return _guard(() async {
      await _dio.patch<dynamic>(
        '/DocumentItems/Update',
        queryParameters: _companyQuery,
        data: body,
        options: _json,
      );
    });
  }

  /// `DELETE /DocumentItems/Delete` — gives back the stock the line moved.
  Future<void> deleteDocumentItem({required int id}) {
    return _guard(() async {
      await _dio.delete<dynamic>(
        '/DocumentItems/Delete',
        queryParameters: {'id': id, ..._companyQuery},
      );
    });
  }

  /// The ids of the taxes on one line (`GET /DocumentItemTaxes/GetByDocumentItemId`).
  Future<List<int>> fetchDocumentItemTaxIds({
    required int documentItemId,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final response = await _dio.get<dynamic>(
        '/DocumentItemTaxes/GetByDocumentItemId',
        queryParameters: {'documentItemId': documentItemId, ..._companyQuery},
        cancelToken: cancelToken,
      );
      return asList(response.data, (json) => asInt(json['taxId']));
    });
  }

  /// `POST /DocumentItemTaxes/Add` — the server then rewrites the line's price
  /// and total with the tax in them.
  Future<void> addDocumentItemTax({
    required int documentItemId,
    required int taxId,
  }) {
    return _guard(() async {
      await _dio.post<dynamic>(
        '/DocumentItemTaxes/Add',
        queryParameters: _companyQuery,
        data: {'documentItemId': documentItemId, 'taxId': taxId},
        options: _json,
      );
    });
  }

  Future<void> deleteDocumentItemTax({
    required int documentItemId,
    required int taxId,
  }) {
    return _guard(() async {
      await _dio.delete<dynamic>(
        '/DocumentItemTaxes/Delete',
        queryParameters: {
          'documentItemId': documentItemId,
          'taxId': taxId,
          ..._companyQuery,
        },
      );
    });
  }

  /// The id of a row the server just created, from either `{ id }` or
  /// `{ data: { id } }`, in either casing.
  static int _createdId(Object? body, String what) {
    Object? source = body;
    if (source is Map && (source['data'] ?? source['Data']) is Map) {
      source = source['data'] ?? source['Data'];
    }
    final id = source is Map ? asIntOrNull(source['id'] ?? source['Id']) : null;
    if (id == null || id <= 0) {
      throw ApiException('The server did not return the new $what.');
    }
    return id;
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
        options: _json,
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
