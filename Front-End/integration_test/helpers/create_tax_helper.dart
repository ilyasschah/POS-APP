/// `createTax` — one tax rate, through Management → Tax rates.
///
/// ```dart
/// await createTax(tester, ctx);                       // VAT 20%, generated code
/// await createTax(tester, ctx, name: 'Reduced', ratePercent: '7');
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../config/test_config.dart';
import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Creates a tax rate and records it on [ctx] as `taxName` / `taxCode`.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
///
/// Every argument is optional, because most tests do not care what the tax is
/// called — only that a product can carry one. What they get by default:
///
/// * [name] — `VAT 20% [E2E 09061412]`
/// * [code] — `V09061412`
/// * [ratePercent] — [kTaxRatePercent]
///
/// 🚨 The code is generated per run and must stay that way. `Tax.Code` carries
/// `UQ_Tax_Code_PerCompany`, a unique index on (CompanyId, Code) — a fixed
/// literal passes on a clean company and then fails every single re-run with a
/// uniqueness error that reads like a regression in the save path.
Future<String> createTax(
  WidgetTester tester,
  E2EContext ctx, {
  String? name,
  String? code,
  String? ratePercent,
}) async {
  final taxName = name ?? tagged('VAT ${ratePercent ?? kTaxRatePercent}%');
  final taxCode = code ?? 'V$kRunDigits';
  final rate = ratePercent ?? kTaxRatePercent;

  await ensureManagementSection(tester, ctx.l, ctx.l.taxRatesLower);
  step('Tax rates opened');

  await tapVisible(tester, find.text(ctx.l.newTaxRate));
  await waitFor(tester, find.widgetWithText(TextFormField, ctx.l.nameRequired));

  // 🚨 These are the TAX form's labels. `productNameRequired` and
  // `productCodeSku` read almost the same on screen but belong to the product
  // dialog — using them here compiles perfectly and finds nothing at run time.
  await fillField(tester, ctx.l.nameRequired, taxName);
  await fillField(tester, ctx.l.codeRequired, taxCode);
  await fillField(tester, ctx.l.rateRequired, rate);

  await tapVisible(
    tester,
    find.widgetWithText(ElevatedButton, ctx.l.actionSave),
  );
  await pumpFor(tester, const Duration(seconds: 3));

  // 🚨 Filter the list before looking for the row. A freshly created tax lands
  // below the fold of a scrollable table, and a ListView builds only what it is
  // showing — so `find.text` reports it missing while the database has it. This
  // gets likelier every run, because these tests leave their rows behind.
  await searchList(tester, taxName);
  await waitFor(
    tester,
    find.textContaining(taxName),
    timeout: const Duration(seconds: 60),
    because: 'The new tax never reached the list.',
  );
  await clearSearch(tester);

  ctx
    ..taxName = taxName
    ..taxCode = taxCode
    ..taxRatePercent = rate;
  ctx.record(E2EArtifact(
    table: 'Tax',
    name: taxName,
    code: taxCode,
    extra: {'Rate': double.parse(rate)},
  ));

  step('Tax created: $taxName ($taxCode) at $rate%');
  return taxName;
}
