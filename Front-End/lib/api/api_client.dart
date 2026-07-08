import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pos_app/auth/auth_token_cache.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/api/customer_discount_models.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/document/document_type_constants.dart';

/// Compiled-in default API endpoint, used until a device-local override is set.
const String kDefaultApiBaseUrl = 'http://192.168.11.103:5002/api';

/// The active API base URL. Held in memory (seeded from SharedPreferences at
/// boot via [initApiBaseUrl]) so the sync/synchronous [createDio] never awaits.
/// It's a PER-DEVICE connection setting — you need it before you can sync — so
/// it lives in local prefs, not the cloud-synced app_properties.
String _apiBaseUrl = kDefaultApiBaseUrl;

const String kApiBaseUrlPrefKey = 'api_base_url';

/// Seed the base URL from SharedPreferences. Call once at boot BEFORE the first
/// network request. A blank/absent override falls back to [kDefaultApiBaseUrl].
void initApiBaseUrl(String? stored) {
  final v = stored?.trim();
  if (v != null && v.isNotEmpty) _apiBaseUrl = v;
}

/// Update the active base URL at runtime (when the operator edits the setting).
void setApiBaseUrl(String url) {
  final v = url.trim();
  _apiBaseUrl = v.isEmpty ? kDefaultApiBaseUrl : v;
}

String get apiBaseUrl => _apiBaseUrl;

Dio createDio() {
  final dio = Dio();

  dio.options.baseUrl = _apiBaseUrl;
  dio.options.connectTimeout = const Duration(seconds: 10);
  dio.options.receiveTimeout = const Duration(seconds: 10);

  // Global auth: attach the active JWT to every request unless a caller has
  // already set an explicit Authorization header. Reads from an in-memory cache
  // (loaded from secure storage once) — never per-request file I/O.
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (!options.headers.containsKey('Authorization')) {
        final jwt = await AuthTokenCache.get();
        if (jwt != null && jwt.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $jwt';
        }
      }
      handler.next(options);
    },
  ));

  if (!kIsWeb) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
      return client;
    };
  }
  return dio;
}

class BulkAddResponse {
  final bool success;
  final List<String> warnings;
  final String? message;

  BulkAddResponse({
    required this.success,
    this.warnings = const [],
    this.message,
  });

  factory BulkAddResponse.fromJson(Map<String, dynamic> json) {
    return BulkAddResponse(
      success: json['success'] ?? false,
      warnings: List<String>.from(json['warnings'] ?? []),
      message: json['message'],
    );
  }
}

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = createDio();
  }
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<List<MenuCategory>> getFullMenu(int companyId, int warehouseId) async {
    try {
      final response = await _dio.get(
        '/Menu',
        queryParameters: {'companyId': companyId, 'warehouseId': warehouseId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => MenuCategory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load menu. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching menu: $e');
    }
  }

  Future<Map<String, dynamic>> bulkAddPosOrderItems(
    int companyId,
    int warehouseId,
    List<CartItem> items,
    double orderTotal,
  ) async {
    try {
      final List<Map<String, dynamic>> jsonList = items
          .map((item) => item.toJson())
          .toList();

      final response = await _dio.post(
        '/PosOrderItem/BulkAdd',
        queryParameters: {'companyId': companyId, 'warehouseId': warehouseId, 'orderTotal': orderTotal},
        data: jsonList,
      );

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 && e.response?.data != null) {
        return e.response!.data;
      }
      throw Exception('Error saving cart: ${e.message}');
    } catch (e) {
      throw Exception('Error saving cart: $e');
    }
  }

  Future<bool> checkoutPosOrder(
    int companyId,
    int userId,
    CheckoutRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/PosOrder/Checkout',
        queryParameters: {'companyId': companyId, 'userId': userId},
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Checkout failed. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during checkout: $e');
    }
  }

  Future<int> createPosOrder(
    int companyId,
    int userId,
    int serviceType,
    int? floorPlanTableId,
    String orderLabel,
    int warehouseId, {
    int? bookingId,
    int? customerId,
  }) async {
    try {
      final response = await _dio.post(
        '/PosOrder/Create',
        queryParameters: {'companyId': companyId},
        data: {
          "userId": userId,
          "number": "ORD-$orderLabel",
          "discount": 0.0,
          "discountType": 0,
          "total": 0.0,
          "customerId": customerId,
          "serviceType": serviceType,
          "serviceStatus": 1,
          "floorPlanTableId": floorPlanTableId,
          "warehouseId": warehouseId,
          "bookingId": bookingId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is int) return data;
        if (data['id'] != null) return data['id'];
        if (data['Id'] != null) return data['Id'];

        throw Exception('Could not find Order ID in response');
      } else {
        throw Exception(
          'Failed to create order. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  Future<bool> updatePosOrder(
    int companyId,
    Map<String, dynamic> request,
  ) async {
    try {
      final response = await _dio.patch(
        '/PosOrder/Update',
        queryParameters: {'companyId': companyId},
        data: request,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  Future<Map<String, dynamic>> getPosOrderById(int companyId, int id) async {
    try {
      final response = await _dio.get(
        '/PosOrder/GetById',
        queryParameters: {'id': id, 'companyId': companyId},
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }

  Future<Map<String, dynamic>?> getActiveOrderForTable(
    int companyId,
    int tableId,
  ) async {
    try {
      final response = await _dio.get(
        '/PosOrder/GetAll',
        queryParameters: {'companyId': companyId},
      );
      if (response.statusCode == 200) {
        final List<dynamic> orders = response.data;
        orders.sort((a, b) {
          final idA = a['id'] ?? a['Id'] ?? 0;
          final idB = b['id'] ?? b['Id'] ?? 0;
          return idB.compareTo(idA);
        });

        return orders.firstWhere(
          (o) =>
              (o['floorPlanTableId'] ?? o['FloorPlanTableId']) == tableId &&
              (o['serviceStatus'] ?? o['ServiceStatus'] ?? 0) > 0,
          orElse: () => null,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch active order: $e');
    }
  }

  Future<bool> occupyFloorPlanTable(int companyId, int tableId) async {
    try {
      final response = await _dio.patch(
        '/FloorPlanTables/OccupyTable',
        queryParameters: {'companyId': companyId, 'tableId': tableId},
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to occupy table: $e');
    }
  }

  Future<bool> freeFloorPlanTable(int companyId, int tableId) async {
    try {
      final response = await _dio.patch(
        '/FloorPlanTables/FreeTable',
        queryParameters: {'companyId': companyId, 'tableId': tableId},
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to free table: $e');
    }
  }

  Future<List<dynamic>> getOrderItems(int companyId, int posOrderId) async {
    try {
      final response = await _dio.get(
        '/PosOrderItem/GetByOrderId',
        queryParameters: {'posOrderId': posOrderId, 'companyId': companyId},
      );
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch order items: $e');
    }
  }

  Future<bool> deletePosOrder(
    int companyId,
    int posOrderId,
    int warehouseId,
  ) async {
    try {
      final response = await _dio.delete(
        '/PosOrder/Delete',
        queryParameters: {
          'id': posOrderId,
          'companyId': companyId,
          'warehouseId': warehouseId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  Future<bool> voidPosOrder(
    int companyId,
    int posOrderId,
    int warehouseId, {
    int documentTypeId = DocumentTypes.sales,
  }) async {
    try {
      final response = await _dio.post(
        '/PosOrder/Void',
        queryParameters: {
          'posOrderId': posOrderId,
          'companyId': companyId,
          'warehouseId': warehouseId,
          'documentTypeId': documentTypeId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to void order: $e');
    }
  }

  // --- Stock Management ---
  Future<bool> addStock(
    int companyId,
    int productId,
    int warehouseId,
    double quantity,
  ) async {
    try {
      final response = await _dio.post(
        '/Stocks/Add',
        queryParameters: {'companyId': companyId},
        data: {
          'productId': productId,
          'warehouseId': warehouseId,
          'quantity': quantity,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Failed to add stock: $e');
    }
  }

  Future<bool> updateStock(
    int companyId,
    int stockId,
    int productId,
    int warehouseId,
    double quantity,
  ) async {
    try {
      final response = await _dio.patch(
        '/Stocks/Update',
        queryParameters: {'companyId': companyId},
        data: {
          'id': stockId,
          'newProductId': productId,
          'newWarehouseId': warehouseId,
          'newQuantity': quantity,
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }

  Future<bool> deleteStock(int companyId, int stockId) async {
    try {
      final response = await _dio.delete(
        '/Stocks/Delete',
        queryParameters: {'id': stockId, 'companyId': companyId},
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to delete stock: $e');
    }
  }

  Future<List<dynamic>> getAllActiveOrders(int companyId) async {
    try {
      final response = await _dio.get(
        '/PosOrder/GetAll',
        queryParameters: {'companyId': companyId},
      );
      if (response.statusCode == 200) {
        final List<dynamic> orders = response.data;
        final activeOrders = orders
            .where((o) => (o['serviceStatus'] ?? o['ServiceStatus'] ?? 0) > 0)
            .toList();
        activeOrders.sort((a, b) {
          final idA = a['id'] ?? a['Id'] ?? 0;
          final idB = b['id'] ?? b['Id'] ?? 0;
          return (idB as int).compareTo(idA as int);
        });
        return activeOrders;
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch active orders: ${e.message}');
    }
  }

  Future<List<dynamic>> getAllPosOrders(int companyId) async {
    try {
      final response = await _dio.get(
        '/PosOrder/GetAll',
        queryParameters: {'companyId': companyId},
      );
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch orders: ${e.message}');
    }
  }

  Future<List<dynamic>> getAllDocuments(int companyId) async {
    try {
      final response = await _dio.get(
        '/Document/GetAll',
        queryParameters: {'companyId': companyId},
      );
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch documents: ${e.message}');
    }
  }

  // --- Bookings ---
  Future<List<dynamic>> getBookings(int companyId) async {
    try {
      final response = await _dio.get(
        '/Bookings/GetAll',
        queryParameters: {'companyId': companyId},
      );
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  Future<Map<String, dynamic>> createBooking(
    int companyId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/Bookings/Add',
        queryParameters: {'companyId': companyId},
        data: data,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  Future<bool> updateBooking(
    int companyId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/Bookings/Update',
        queryParameters: {'companyId': companyId},
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update booking: $e');
    }
  }

  Future<bool> updateBookingStatus(
    int companyId,
    int bookingId,
    int status, {
    int? documentId,
  }) async {
    try {
      final response = await _dio.patch(
        '/Bookings/UpdateStatus',
        queryParameters: {'companyId': companyId},
        data: {
          'bookingId': bookingId,
          'status': status,
          'documentId': documentId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  Future<bool> updateBookingResource(
    int companyId,
    int bookingId, {
    int? userId,
    int? floorPlanTableId,
  }) async {
    try {
      final response = await _dio.patch(
        '/Bookings/UpdateResource',
        queryParameters: {'companyId': companyId},
        data: {
          'bookingId': bookingId,
          'userId': userId,
          'floorPlanTableId': floorPlanTableId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to update booking resource: $e');
    }
  }

  Future<bool> deleteBooking(
    int companyId,
    int bookingId,
    int warehouseId,
  ) async {
    try {
      final response = await _dio.delete(
        '/Bookings/Delete',
        queryParameters: {
          'companyId': companyId,
          'id': bookingId,
          'warehouseid': warehouseId,
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      // Throw (don't swallow) so the caller can surface the failure and keep
      // the booking on screen — returning false made offline deletes look
      // successful, then the row reappeared on the next pull.
      throw Exception('Failed to delete booking: $e');
    }
  }

  // --- Promotions ---
  Future<List<PromotionDto>> getActivePromotions(int companyId) async {
    try {
      final response = await _dio.get(
        '/Promotions/GetActive',
        queryParameters: {'companyId': companyId},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PromotionDto.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error fetching active promotions: $e');
    }
  }

  Future<List<PromotionDto>> getAllPromotions(int companyId) async {
    try {
      final response = await _dio.get(
        '/Promotions/GetAll',
        queryParameters: {'companyId': companyId},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) {
              try {
                return PromotionDto.fromJson(json);
              } catch (e) {
                debugPrint("Error parsing promotion: $e");
                return null;
              }
            })
            .whereType<PromotionDto>()
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching all promotions: $e');
      return [];
    }
  }

  Future<PromotionDto> createPromotion(
    int companyId,
    CreatePromotionRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/Promotions/Add',
        queryParameters: {'companyId': companyId},
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PromotionDto.fromJson(response.data);
      }
      throw Exception('Failed to create promotion');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> updatePromotion(
    int companyId,
    UpdatePromotionRequest request,
  ) async {
    try {
      final response = await _dio.put(
        '/Promotions/Update',
        queryParameters: {'companyId': companyId},
        data: request.toJson(),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> deletePromotion(int companyId, int promotionId) async {
    try {
      final response = await _dio.delete(
        '/Promotions/Delete',
        queryParameters: {'companyId': companyId, 'id': promotionId},
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // --- Company ---
  Future<Company> getCompanyById(int id) async {
    try {
      final response = await _dio.get(
        '/Company/GetById',
        queryParameters: {'id': id},
      );
      return Company.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to fetch company: ${e.message}');
    }
  }

  Future<bool> updateCompanyLogo(int companyId, String base64Logo) async {
    try {
      final response = await _dio.put(
        '/Company/UpdateLogo',
        data: {'id': companyId, 'logo': base64Logo},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Failed to update logo: ${e.message}');
    }
  }

  // --- Stock Controls ---
  Future<void> createStockControl(
    int companyId, {
    required int productId,
    int? customerId,
    double reorderPoint = 0,
    double preferredQuantity = 0,
    bool isLowStockWarningEnabled = true,
    double lowStockWarningQuantity = 0,
  }) async {
    try {
      await _dio.post(
        '/StockControls/Add',
        queryParameters: {'companyId': companyId},
        data: {
          'productId': productId,
          if (customerId != null) 'customerId': customerId,
          'reorderPoint': reorderPoint,
          'preferredQuantity': preferredQuantity,
          'isLowStockWarningEnabled': isLowStockWarningEnabled,
          'lowStockWarningQuantity': lowStockWarningQuantity,
        },
      );
    } catch (e) {
      throw Exception('Failed to create stock control: $e');
    }
  }

  Future<void> updateStockControl(
    int companyId, {
    required int id,
    int? customerId,
    double? reorderPoint,
    double? preferredQuantity,
    bool? isLowStockWarningEnabled,
    double? lowStockWarningQuantity,
  }) async {
    try {
      await _dio.patch(
        '/StockControls/Update',
        queryParameters: {'companyId': companyId},
        data: {
          'id': id,
          if (customerId != null) 'customerId': customerId,
          if (reorderPoint != null) 'reorderPoint': reorderPoint,
          if (preferredQuantity != null) 'preferredQuantity': preferredQuantity,
          if (isLowStockWarningEnabled != null)
            'isLowStockWarningEnabled': isLowStockWarningEnabled,
          if (lowStockWarningQuantity != null)
            'lowStockWarningQuantity': lowStockWarningQuantity,
        },
      );
    } catch (e) {
      throw Exception('Failed to update stock control: $e');
    }
  }

  Future<void> deleteStockControl(int companyId, int id) async {
    try {
      await _dio.delete(
        '/StockControls/Delete',
        queryParameters: {'id': id, 'companyId': companyId},
      );
    } catch (e) {
      throw Exception('Failed to delete stock control: $e');
    }
  }

  // --- Customer Discounts ---
  Future<CustomerDiscountDto?> getCustomerDiscount(
    int companyId,
    int customerId,
  ) async {
    try {
      final response = await _dio.get(
        '/CustomerDiscounts/GetByCustomerId',
        queryParameters: {'companyId': companyId, 'customerId': customerId},
      );
      if (response.statusCode == 200 && response.data != null) {
        return CustomerDiscountDto.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<CustomerDiscountDto> createCustomerDiscount(
    int companyId,
    CreateCustomerDiscountRequest request,
  ) async {
    try {
      final response = await _dio.post(
        // Backend route is [HttpPost("Add")] — NOT "Create" (that 404s).
        '/CustomerDiscounts/Add',
        queryParameters: {'companyId': companyId},
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CustomerDiscountDto.fromJson(response.data);
      }
      throw Exception('Failed to create customer discount');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> updateCustomerDiscount(
    int companyId,
    UpdateCustomerDiscountRequest request,
  ) async {
    try {
      final response = await _dio.patch(
        '/CustomerDiscounts/Update',
        queryParameters: {'companyId': companyId},
        data: request.toJson(),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<bool> deleteCustomerDiscount(int companyId, int discountId) async {
    try {
      final response = await _dio.delete(
        '/CustomerDiscounts/Delete',
        queryParameters: {'companyId': companyId, 'id': discountId},
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
