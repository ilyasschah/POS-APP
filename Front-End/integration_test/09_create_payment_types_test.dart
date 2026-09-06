// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 09_create_payment_types — the tender kinds a till can take money on.
//
//   cd Front-End
//   flutter test integration_test/09_create_payment_types_test.dart -d windows
//
// ── Three types, because they are three different features ──────────────────
//
//   Card      markAsPaid ✓  customerRequired ✗   an ordinary non-cash sale
//   Account   markAsPaid ✗  customerRequired ✓   a CREDIT/tab: banks UNPAID
//   Voucher   markAsPaid ✓  customerRequired ✗   a second paid type, for SPLIT payment
//
// 🚨 `markAsPaid: false` is not a variation on cash — it changes what the sale
// IS. A credit sale completes with nothing tendered and banks with an
// outstanding balance, so a payment assertion written for cash would pass
// against a sale that took no money at all. That is exactly why `makeSale`
// picks `markAsPaid && !isCustomerRequired` when the caller names no type.
//
// 🚨 `isCustomerRequired` is blocked outright for the walk-in customer `C000`,
// by name, in the checkout. So "Account" is unusable until `07_create_customer`
// has run — which is why it sits after it in the chain rather than before.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/cart/payment_type_provider.dart';

import 'helpers/create_payment_type_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create_payment_types', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    final card = await createPaymentType(
      tester,
      ctx,
      name: tagged('Card'),
      markAsPaid: true,
    );

    final voucher = await createPaymentType(
      tester,
      ctx,
      name: tagged('Voucher'),
      markAsPaid: true,
    );

    final account = await createPaymentType(
      tester,
      ctx,
      name: tagged('Account'),
      markAsPaid: false,
      customerRequired: true,
    );

    // ── The shapes the sale tests will branch on ──────────────────────────────
    //
    // 🚨 Read back from `allPaymentTypesProvider`, which is what the CHECKOUT
    // reads. A type the management table lists but that provider filters out
    // would be invisible to every sale test downstream — and that is a real
    // failure mode, not a hypothetical: the provider filters on `isEnabled`.
    final types = ctx.container.read(allPaymentTypesProvider).value ?? const [];

    final paid = types.where((t) => t.markAsPaid && !t.isCustomerRequired);
    expect(
      paid.length,
      greaterThanOrEqualTo(2),
      reason: 'Split payment needs two types that can each take money now; '
          'this company has ${paid.length}.',
    );

    final credit = types.where((t) => !t.markAsPaid);
    expect(
      credit,
      isNotEmpty,
      reason: 'No credit type — R21 (a sale that banks UNPAID) cannot be '
          'written without one.',
    );

    final needsCustomer = types.where((t) => t.isCustomerRequired);
    expect(
      needsCustomer,
      isNotEmpty,
      reason: 'No customer-required type — R22 (the walk-in is refused by name) '
          'cannot be written without one.',
    );

    step('create_payment_types PASSED — "$card" and "$voucher" take money now, '
        '"$account" banks unpaid and demands a customer');
  });
}
