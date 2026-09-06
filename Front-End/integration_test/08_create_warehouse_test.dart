// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 08_create_warehouse — a SECOND stock location.
//
//   cd Front-End
//   flutter test integration_test/08_create_warehouse_test.dart -d windows
//
// ── Why it matters ──────────────────────────────────────────────────────────
//
// Warehouse allocation happens at the ITEM level, not the cart level: one cart
// can take Product A from warehouse A and Product B from warehouse B (the
// split-sourcing rule in CLAUDE.md). With a single warehouse that logic is real
// but untestable — every line resolves to the same place, so a sourcing bug is
// indistinguishable from a working system.
//
// The out-of-stock contract needs it too. A business-logic 400 carries
// `fallbackWarehouses`, and a company with one warehouse can never produce a
// non-empty list — so the dialog that offers them cannot be exercised either.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/stock/warehouse_provider.dart';

import 'helpers/create_warehouse_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create_warehouse', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    final second = await createWarehouse(tester, ctx, name: tagged('Back Store'));

    // ── At least two, and the new one among them ──────────────────────────────
    //
    // 🚨 Asserted on the COUNT as well as the name, because "the warehouse was
    // created" is not the claim that matters downstream — "this company can now
    // source from more than one place" is. A company that somehow lost its
    // original would satisfy the name check and still break split sourcing.
    final all = ctx.container.read(allWarehousesProvider).value ?? const [];
    expect(
      all.length,
      greaterThanOrEqualTo(2),
      reason: 'Split sourcing needs at least two warehouses; this company has '
          '${all.length}: ${all.map((w) => w.name).join(', ')}',
    );
    expect(all.map((w) => w.name), contains(second));

    step('create_warehouse PASSED — ${all.length} warehouses, newest "$second"');
  });
}
