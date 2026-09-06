/// `createCustomer` — a real, named customer through Management.
///
/// ```dart
/// final customer = await createCustomer(tester, ctx);
/// ```
///
/// ## Why a real customer is needed at all
///
/// Every sale the rest of the suite rings up goes to the WALK-IN customer, code
/// `C000` — and a walk-in is not a customer as far as testing is concerned:
///
///   * it cannot be sold to on credit: the checkout blocks any payment type with
///     `isCustomerRequired` and rejects `C000` BY NAME, so the credit/tab path is
///     unreachable without a real one;
///   * it carries no customer-discount profile, so that path is dead;
///   * it carries no loyalty card, so points can be neither earned nor redeemed.
///
/// ## 🚨 Online-first — unlike the rest of Management
///
/// Creating a customer is NOT the offline-first flow the catalogue screens use.
/// The form writes an optimistic row under a NEGATIVE temp id, POSTs to
/// `/Customer/AddCustomercommand` immediately, then swaps that row for one keyed
/// by the server's id and marks it `synced` — all before the dialog closes.
///
/// So there is no sync step here, and the assertion that matters is that the id
/// is **positive**: the offline path leaves the negative temp row in place and
/// says "saved offline, will sync", which means "there is a customer row" is
/// also true for a customer the server has never heard of.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Creates a customer, proves the server issued its id, and records it.
///
/// Every argument is optional — the defaults are tagged with the run so a row
/// traces back to the run that made it and a re-run cannot collide.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
Future<E2ECustomer> createCustomer(
  WidgetTester tester,
  E2EContext ctx, {
  String? name,
  String? code,
  String? email,
  String? phone,
  String city = 'Casablanca',
  String postalCode = '20000',
  String street = 'Boulevard Zerktouni',
}) async {
  final customerName = name ?? tagged('Fatima Zahra');
  final customerCode = code ?? 'C$kRunDigits';
  final customerEmail = email ?? 'customer.$kRunDigits@octopus-e2e.test';
  final customerPhone = phone ?? '+2126$kRunDigits';

  await ensureManagementSection(tester, ctx.l, ctx.l.customersSuppliersLower);
  await waitFor(
    tester,
    find.byIcon(Icons.person_add),
    timeout: const Duration(seconds: 30),
    because: 'Management did not land on Customers & Suppliers.',
  );
  step('Customers & Suppliers opened');

  await tapVisible(tester, find.byIcon(Icons.person_add));
  await waitFor(
    tester,
    find.text(ctx.l.addCustomerSupplier),
    timeout: const Duration(seconds: 30),
    because: 'The customer form never opened.',
  );

  // "Customer" is ticked by default and "Supplier" is not, which is exactly what
  // a customer to sell to should be — so the checkboxes are left alone rather
  // than blindly toggled.
  await fillField(tester, ctx.l.nameRequired, customerName);
  await fillField(tester, ctx.l.fieldCode, customerCode);
  await fillField(tester, ctx.l.fieldEmail, customerEmail);
  await fillField(tester, ctx.l.phoneNumber, customerPhone);
  await fillField(tester, ctx.l.cityLabel, city);
  await fillField(tester, ctx.l.postalCode, postalCode);
  await fillField(tester, ctx.l.streetName, street);
  await fillField(tester, ctx.l.taxNumber, 'TAX$kRunDigits');

  await tapVisible(
    tester,
    find.widgetWithText(ElevatedButton, ctx.l.actionSave),
  );

  // The dialog pops on success, so its title going away IS the save landing.
  await waitForGone(
    tester,
    find.text(ctx.l.addCustomerSupplier),
    timeout: const Duration(seconds: 90),
    because: 'The customer form stayed open — the save did not complete.',
  );

  // ── Saved locally, with a SERVER id ────────────────────────────────────────
  final db = ctx.container.read(appDatabaseProvider);
  late CustomersTableData saved;
  await waitUntil(
    tester,
    () async {
      final rows = await (db.select(db.customersTable)
            ..where((t) => t.companyId.equals(ctx.company.companyId))
            ..where((t) => t.name.equals(customerName)))
          .get();
      final match = rows.where((c) => c.id > 0).firstOrNull;
      if (match == null) return false;
      saved = match;
      return true;
    },
    describe: 'the customer reaches the local database with a server id',
    timeout: const Duration(seconds: 90),
  );

  expect(saved.syncStatus, 'synced',
      reason: 'A customer accepted by the server should not still be queued.');
  expect(saved.code, customerCode);
  expect(saved.email, customerEmail);
  expect(saved.isCustomer, isTrue,
      reason: 'It has to be a CUSTOMER — a supplier cannot be sold to.');
  expect(saved.isEnabled, isTrue);

  // 🚨 Read the provider while still ON the Customers screen.
  // `allCustomersProvider` is autoDispose and that screen is its only listener
  // here — walk away first and this reads `AsyncLoading`, i.e. an empty list,
  // and reports a customer the app cannot see when the truth is that nobody was
  // watching. The checkout's customer picker reads this same provider, so a row
  // it filters out would be useless to the tests this one exists to enable.
  await waitUntil(
    tester,
    () async => (ctx.container.read(allCustomersProvider).value ?? const [])
        .any((c) => c.id == saved.id),
    describe: "the customer appears in the app's own customer list",
    timeout: const Duration(seconds: 60),
  );

  final customer = E2ECustomer(
    customerId: saved.id,
    name: customerName,
    code: customerCode,
    email: customerEmail,
    phone: customerPhone,
  );

  await recordE2ECustomer(
    companyId: ctx.company.companyId,
    customer: customer,
  );

  ctx.record(E2EArtifact(
    table: 'Customer',
    name: customerName,
    code: customerCode,
    extra: {'Id': saved.id, 'Email': customerEmail},
  ));

  step('Customer created: $customerName (id ${saved.id}, $customerCode)');
  return customer;
}
