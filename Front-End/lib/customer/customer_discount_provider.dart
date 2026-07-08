import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/api/customer_discount_models.dart';
import 'package:pos_app/company/company_provider.dart';

final customerDiscountProvider = FutureProvider.family<CustomerDiscountDto?, int>((ref, customerId) async {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return null;
  final api = ApiClient();
  return await api.getCustomerDiscount(company.id, customerId);
});
