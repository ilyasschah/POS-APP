// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 07_create_customer — a REAL customer, recorded where the rest of the suite
// can find it.
//
//   PIN → Management → Customers & Suppliers → new customer
//     → verify locally → verify on the SERVER → write it to the credentials file
//
//   cd Front-End
//   flutter test integration_test/07_create_customer_test.dart -d windows
//
// ── Why it earns a place in the chain ───────────────────────────────────────
//
// Every sale the suite rings up otherwise goes to the WALK-IN customer, `C000`,
// which cannot be sold to on credit, carries no discount profile and holds no
// loyalty card. Three whole areas of the money surface are unreachable without
// a named customer, so this builds one and records it for them.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/api/api_client.dart';

import 'helpers/create_customer_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create_customer', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    final customer = await createCustomer(tester, ctx);

    // ── Saved ONLINE ──────────────────────────────────────────────────────────
    //
    // The local row's id CAME from the server, so this is close to a formality —
    // but it is the difference between "the app says it posted" and "the server
    // has it", and the whole point of recording this customer is that a LATER
    // RUN, days from now, can still rely on it being there.
    //
    // Fetched with `createDio()` rather than ApiClient because `/Customer` has no
    // ApiClient wrapper — the screen talks to it directly.
    final res = await createDio().get<dynamic>(
      '/Customer/GetCustomerById',
      queryParameters: {
        'Id': customer.customerId,
        'companyId': ctx.company.companyId,
      },
    );
    final online = res.data as Map<String, dynamic>;
    expect(online['id'], customer.customerId);
    expect(online['name'], customer.name);
    expect(online['code'], customer.code);
    step('Server confirms customer ${online['id']}');

    // Read it back through the same helper a later test will use, so a broken
    // WRITER fails here rather than in whatever test tries to depend on it.
    final recorded = await loadE2ECustomer(companyId: ctx.company.companyId);
    expect(recorded.customerId, customer.customerId);
    expect(recorded.name, customer.name);

    step('create_customer PASSED — ${customer.name} '
        '(id ${customer.customerId}) recorded for company '
        '${ctx.company.companyId}');
  });
}
