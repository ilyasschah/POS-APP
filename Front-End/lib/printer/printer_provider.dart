import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'printer_selection_model.dart';
import 'printer_selection_settings_model.dart';

final allPrinterSelectionsProvider =
    FutureProvider.autoDispose<List<PrinterSelectionModel>>((ref) async {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) {
    throw Exception(
        'No company selected. Please log in and select a company first.');
  }
  final dio = createDio();
  final res = await dio.get(
    '/PosPrinterSelections/GetAll',
    queryParameters: {'companyId': company.id},
  );
  return (res.data as List)
      .map((j) => PrinterSelectionModel.fromJson(j))
      .toList();
});

final printerSelectionSettingsByIdProvider =
    FutureProvider.autoDispose.family<PrinterSelectionSettingsModel?, int>(
        (ref, selectionId) async {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return null;
  final dio = createDio();
  try {
    final res = await dio.get(
      '/PosPrinterSelectionSettings/GetBySelectionId/$selectionId',
      queryParameters: {'companyId': company.id},
    );
    final list = res.data as List?;
    if (list == null || list.isEmpty) return null;
    return PrinterSelectionSettingsModel.fromJson(list.first);
  } catch (_) {
    return null;
  }
});
