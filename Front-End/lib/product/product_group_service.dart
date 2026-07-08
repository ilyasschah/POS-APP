import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/product/product_group_model.dart';

final productGroupServiceProvider = Provider<ProductGroupService>((ref) {
  return ProductGroupService(createDio());
});

class ProductGroupService {
  final Dio _dio;

  ProductGroupService(this._dio);

  Future<List<ProductGroup>> getAll(int companyId) async {
    final response = await _dio.get(
      '/ProductGroups/GetAll',
      queryParameters: {'companyId': companyId},
    );
    return (response.data as List).map((j) => ProductGroup.fromJson(j)).toList();
  }

  Future<List<dynamic>> getChildren(int parentId, int companyId) async {
    final response = await _dio.get(
      '/ProductGroups/GetChildren',
      queryParameters: {'parentId': parentId, 'companyId': companyId},
    );
    return response.data as List;
  }

  Future<List<dynamic>> getProductsByGroup(int productGroupId, int companyId) async {
    final response = await _dio.get(
      '/Products/GetByProductGroup',
      queryParameters: {'productGroupId': productGroupId, 'companyId': companyId},
    );
    return response.data as List;
  }

  Future<void> add(int companyId, Map<String, dynamic> payload) async {
    await _dio.post(
      '/ProductGroups/Add',
      queryParameters: {'companyId': companyId},
      data: payload,
    );
  }

  Future<void> update(int companyId, Map<String, dynamic> payload) async {
    await _dio.patch(
      '/ProductGroups/Update',
      queryParameters: {'companyId': companyId},
      data: payload,
    );
  }

  Future<void> delete(int id, int companyId) async {
    await _dio.delete(
      '/ProductGroups/Delete',
      queryParameters: {'id': id, 'companyId': companyId},
    );
  }

  Future<int> assignProducts(
      int companyId, int groupId, List<int> productIds) async {
    final response = await _dio.post(
      '/ProductGroups/AssignProducts',
      data: {
        'companyId': companyId,
        'groupId': groupId,
        'productIds': productIds,
      },
    );
    return (response.data['updated'] as int?) ?? 0;
  }
}
