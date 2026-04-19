import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://localhost:7002/api';
    _dio.options.connectTimeout = const Duration(seconds: 10);

    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        if (kDebugMode) {
          client.badCertificateCallback = (cert, host, port) => true;
        }
        return client;
      };
    }
  }

  // 1. Fetch Companies for the setup screen
  Future<List<dynamic>> getCompanies() async {
    try {
      final response = await _dio.get('/Company/GetAll');
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to load companies: $e');
    }
  }

  // 2. Fetch the Kitchen Orders
  Future<List<dynamic>> getKitchenOrders(int companyId) async {
    try {
      final response = await _dio.get(
        '/PosOrder/GetKitchenOrders',
        queryParameters: {'companyId': companyId},
      );
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to fetch kitchen orders: $e');
    }
  }
}
