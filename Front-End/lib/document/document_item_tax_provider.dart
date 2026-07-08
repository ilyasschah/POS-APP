import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/document/document_item_tax_model.dart';

final documentItemTaxesProvider = FutureProvider.autoDispose.family<List<DocumentItemTaxModel>, int>((ref, documentItemId) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  try {
    final dio = createDio();
    final res = await dio.get(
      '/DocumentItemTaxes/GetByDocumentItemId',
      queryParameters: {'documentItemId': documentItemId, 'companyId': companyId},
    );
    return (res.data as List).map((x) => DocumentItemTaxModel.fromJson(x)).toList();
  } catch (e) {
    return [];
  }
});