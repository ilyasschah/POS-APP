import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/document/document_item_expiration_date_model.dart';

final documentItemExpirationDateProvider = FutureProvider.autoDispose
    .family<DocumentItemExpirationDateModel?, int>((ref, documentItemId) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return null;

  try {
    final dio = createDio();
    final res = await dio.get(
      '/DocumentItemExpirationDates/Get',
      queryParameters: {
        'documentItemId': documentItemId,
        'companyId': companyId
      },
    );

    if (res.data != null) {
      return DocumentItemExpirationDateModel.fromJson(res.data);
    }
    return null;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) {
      return null;
    }
    rethrow;
  } catch (e) {
    return null;
  }
});
