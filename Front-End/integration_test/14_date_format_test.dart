// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 14_date_format — one setting drives every date on every screen.
//
//   set yyyy-MM-dd  → Sales History and Documents show 2026-09-01
//   set dd/MM/yyyy  → the SAME screens show 01/09/2026
//   restore
//
//   cd Front-End
//   flutter test integration_test/14_date_format_test.dart -d windows
//
// ── The bug this exists for ─────────────────────────────────────────────────
//
// Settings → General → Regional → Date Format had four options and changed
// NOTHING. Every screen built its own 'dd/MM/yyyy'. The fix routed them all
// through `AppDateFormat` — and then MISSED SEVEN SCREENS on the first pass,
// because those never called `DateFormat` at all. They built the date by hand:
//
//     '${_pad(d.day)}/${_pad(d.month)}/${d.year} ${_pad(d.hour)}:${_pad(d.minute)}'
//
// A grep for `DateFormat` cannot see that. The seven were Sales History,
// Documents, POS Session, the Session list, the Document editor, Promotions and
// the Subscription/About rows — plus the printed receipt and Z-report.
//
// 🚨 So the point of THIS test is not that `AppDateFormat` works.
// `test/app_date_format_test.dart` already proves that, in 22 tests, and every
// one of them passed while those seven screens ignored the class completely.
// This test reads the REAL SCREENS, which is the only thing that can catch it.
//
// ── Why it changes the setting TWICE ────────────────────────────────────────
//
// 🚨 Asserting "Sales History shows 2026-09-01 when the setting is yyyy-MM-dd"
// proves nothing on its own — a screen hardcoded to ISO passes it. The setting
// is changed to a second, differently-SHAPED pattern and the same screens are
// read again, so the only way to satisfy both passes is to genuinely follow the
// setting.
//
// And each pass fails on a CONFLICTING shape, not merely on a missing one. A
// hand-rolled `01/09/2026` sitting next to a correct `2026-09-01` is precisely
// the half-migrated state that shipped.
//
// ── It needs the chain to have run ──────────────────────────────────────────
//
// A screen with no dated rows passes any date assertion vacuously, so this reads
// screens that `06_make_sale_retail` leaves rows on. Run the chain first.
//
// ── What is deliberately NOT here ───────────────────────────────────────────
//
// * **dd/MM vs MM/dd.** Both render as `NN/NN/NNNN`; telling them apart on
//   screen needs the exact date of a row this test did not create.
//   `app_date_format_test.dart` owns that — it can construct the input.
// * **CSV exports and file names staying ISO.** Exporting opens the operating
//   system's save dialog, which is outside the Flutter tree — the same reason
//   `03_setup_catalog` cannot set a product image. Unit-tested instead.
// * **The timezone half.** It shares the code path but lives behind an
//   Auto/Manual switch and a long zone list; it deserves its own test rather
//   than a hurried tail on this one. See TEST_PLAN.md X36.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/reports/sales_history_screen.dart';

import 'helpers/date_format_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'support/e2e_support.dart';

/// The two patterns this test switches between.
///
/// 🚨 Chosen because their SHAPES differ — `2026-09-01` against `01/09/2026`.
/// Two patterns that rendered the same way would let a hardcoded screen pass
/// both passes.
const String kIsoPattern = 'yyyy-MM-dd';
const String kSlashedPattern = 'dd/MM/yyyy';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('date_format', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    // Whatever the shop was on, so it can be put back. This is a COMPANY
    // setting — walking away having changed it changes every terminal on it.
    late String original;

    // ── Pass 1 · ISO ──────────────────────────────────────────────────────────
    original = await setDateFormat(tester, ctx, kIsoPattern);
    await _readDatedScreens(tester, ctx, kIsoPattern);

    // ── Pass 2 · slashed ──────────────────────────────────────────────────────
    //
    // 🚨 The pass that gives the test its teeth. Everything asserted above is
    // also true of a screen that hardcodes ISO; nothing here is true of one.
    await setDateFormat(tester, ctx, kSlashedPattern);
    await _readDatedScreens(tester, ctx, kSlashedPattern);

    // ── Restore ───────────────────────────────────────────────────────────────
    await setDateFormat(tester, ctx, original);
    step('date_format PASSED — the screens followed the setting through two '
        'different shapes, restored to "$original"');
  });
}

/// Visits each screen that shows a date and asserts it follows [pattern].
///
/// Sales History and Documents are the two the fix originally missed, and both
/// carry columns with a TIME as well as a date — which is what made the miss so
/// visible and why they are checked first.
Future<void> _readDatedScreens(
  WidgetTester tester,
  E2EContext ctx,
  String pattern,
) async {
  // ── Sales History ──────────────────────────────────────────────────────────
  //
  // 🚨 A TAB, not a pushed route — `PosTab.salesHistory` off the till's sidebar,
  // per the "Ilyass Screen" contract. It also sits behind
  // `SecurityKeys.salesHistory`, so a restricted user gets a denial toast rather
  // than the screen.
  await openSidebar(tester);
  ctx.refreshL10n(tester);
  await tapVisible(tester, find.text(ctx.l.viewSalesHistory));
  await waitFor(
    tester,
    find.byType(SalesHistoryScreen),
    timeout: const Duration(seconds: 60),
    because: 'Sales History did not open. A security key on '
        'SecurityKeys.salesHistory will also look like this.',
  );
  await pumpFor(tester, const Duration(seconds: 3));
  ctx.refreshL10n(tester);

  expectDatesFollow(tester, ctx, pattern: pattern, where: 'Sales History');

  // ── Documents ──────────────────────────────────────────────────────────────
  //
  // Its Date column used to read `01-Sep-26 23:42` — a localized month
  // abbreviation, a shape none of the four settings can produce.
  await ensureManagementSection(tester, ctx.l, ctx.l.documents);
  await pumpFor(tester, const Duration(seconds: 3));
  ctx.refreshL10n(tester);

  expectDatesFollow(tester, ctx, pattern: pattern, where: 'Documents');

  await exitManagement(tester, ctx.l);
}
