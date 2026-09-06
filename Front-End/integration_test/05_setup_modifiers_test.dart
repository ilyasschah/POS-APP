// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 05_setup_modifiers — modifier groups, in BOTH shapes the till can render.
//
//   cd Front-End
//   flutter test integration_test/05_setup_modifiers_test.dart -d windows
//
// ── Why two groups and not one ──────────────────────────────────────────────
//
// A group's min/max pair is not decoration — it is the ONLY thing deciding the
// control the cashier is handed, so the two shapes are genuinely different
// features:
//
//   Extras    min 0 / max 3 → checkboxes; take none, take three; free text on
//   Cup Size  min 1 / max 1 → radios; the sale is BLOCKED until one is chosen
//
// `Cup Size` also carries a NEGATIVE surcharge (Small, −2.00) — legitimate, and
// the reason the price field lets a minus sign through at all.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/create_modifier_group_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/verify_persisted_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup_modifiers', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    // ── Optional-many: checkboxes, free text on ───────────────────────────────
    final extras = await createModifierGroup(
      tester,
      ctx,
      name: tagged('Extras'),
      min: 0,
      max: 3,
      freeText: true,
      ruleLabel: ctx.l.selectionRuleOptionalMany(3),
      options: const [
        E2EModifierOption('Extra shot', '3.00'),
        E2EModifierOption('Oat milk', '2.50'),
        E2EModifierOption('Vanilla syrup', '2.00'),
      ],
    );

    // ── Required-one: radios, and the sale is blocked until one is picked ─────
    final cupSize = await createModifierGroup(
      tester,
      ctx,
      name: tagged('Cup Size'),
      min: 1,
      max: 1,
      freeText: false,
      ruleLabel: ctx.l.selectionRuleExactlyOne,
      options: const [
        // 🚨 A NEGATIVE surcharge. A smaller cup costs less, and this is the
        // case that proves the price field accepts a minus sign at all.
        E2EModifierOption('Small', '-2.00'),
        E2EModifierOption('Medium', '0.00'),
        E2EModifierOption('Large', '4.00'),
      ],
    );

    // ── Local first ───────────────────────────────────────────────────────────
    //
    // 🚨 Content only, NOT the id. A group saved offline holds a temporary
    // NEGATIVE id until the push swaps it, so asserting `id > 0` here would just
    // be asserting that the sync had already happened.
    final localExtras = await awaitModifierGroup(tester, ctx, extras);
    expect(localExtras.minSelections, 0);
    expect(localExtras.maxSelections, 3);
    expect(localExtras.allowsFreeText, isTrue);
    expect(localExtras.options.length, 3);

    final localSize = await awaitModifierGroup(tester, ctx, cupSize);
    expect(localSize.minSelections, 1);
    expect(localSize.maxSelections, 1);
    expect(
      localSize.options.map((o) => o.additionalPrice),
      contains(-2.00),
      reason: 'The negative surcharge did not survive the save.',
    );
    step('Both groups saved locally');

    // ── Then the server ───────────────────────────────────────────────────────
    //
    // 🚨 After the sync the groups have to be found BY NAME again.
    // `remapModifierGroupId` DELETES the negative row and writes a new one under
    // the server's id, so a test holding the old id is looking for a row that no
    // longer exists.
    await exitManagement(tester, ctx.l);
    await syncNow(tester, ctx.l);
    await verifyPersisted(tester, ctx);

    step('setup_modifiers PASSED — 2 groups, both shapes, local and online');
  });
}
