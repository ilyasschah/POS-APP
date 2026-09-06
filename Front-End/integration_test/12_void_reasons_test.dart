// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 12_void_reasons — the list a cashier picks from when cancelling a line.
//
//   cd Front-End
//   flutter test integration_test/12_void_reasons_test.dart -d windows
//
// ── Why it earns a place in the chain ───────────────────────────────────────
//
// `Order.RequireReasonOnVoid` makes the reason mandatory, and the void dialog
// offers exactly what this screen holds. A company with an empty list therefore
// cannot void at all with that setting on — so the void tests (R36, R37) are
// unreachable until something puts rows here.
//
// Three reasons rather than one, because they are three different SHAPES of
// void and a real shop distinguishes them: the customer's choice, the shop's
// mistake, and a genuine fault. Nothing branches on which is used, but a list of
// one cannot show that the picker offers a choice at all.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/void_reason/void_reason_screen.dart';

import 'helpers/create_void_reason_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'support/e2e_support.dart';

/// The reasons this test leaves behind.
///
/// 🚨 NOT run-tagged, unlike most names this suite generates. A void reason is
/// picked from a short list by a cashier under time pressure, and a picker
/// reading "Customer changed mind [E2E 09061612]" three times over is not a list
/// anybody can use. The helper is idempotent by name, so a re-run reuses these
/// rather than stacking near-duplicates — the same reasoning that made
/// `10_create_users` use stable usernames.
const Map<String, String> kVoidReasons = {
  'Customer changed mind': '1',
  'Rang up in error': '2',
  'Damaged item': '3',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('void_reasons', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    for (final entry in kVoidReasons.entries) {
      await createVoidReason(tester, ctx, name: entry.key, rank: entry.value);
    }

    // ── All three reachable by the picker ─────────────────────────────────────
    //
    // 🚨 Read from `voidReasonsProvider`, which is what the VOID DIALOG reads.
    // A row the management list shows but that provider filters out would be
    // invisible to the cashier who has to choose from it — and that is the only
    // consumer that matters here.
    final reasons = ctx.container.read(voidReasonsProvider).value ?? const [];

    for (final name in kVoidReasons.keys) {
      expect(
        reasons.map((r) => r.name),
        contains(name),
        reason: '"$name" is not in the list the void dialog offers.',
      );
    }

    expect(
      reasons.length,
      greaterThanOrEqualTo(kVoidReasons.length),
      reason: 'A void picker needs more than one option to be a choice.',
    );

    // Ranks are what decide the order the cashier sees, so a run that saved the
    // names but dropped the ranks would leave a list ordered by nothing.
    for (final entry in kVoidReasons.entries) {
      final saved = reasons.firstWhere((r) => r.name == entry.key);
      expect(
        saved.rank,
        int.parse(entry.value),
        reason: '"${entry.key}" came back at rank ${saved.rank}, not '
            '${entry.value} — the picker would show them in the wrong order.',
      );
    }

    step('void_reasons PASSED — ${kVoidReasons.length} reasons, '
        '${reasons.length} on the company');
  });
}
