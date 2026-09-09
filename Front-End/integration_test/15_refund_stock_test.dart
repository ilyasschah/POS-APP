// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 15_refund_stock — stock goes down on a sale and back up on a refund, ONCE.
//
//   read the server's stock  → S
//   sell 1 unit → sync       → S − 1
//   refund it   → sync       → S      ← exactly S, never S + 1
//
//   cd Front-End
//   flutter test integration_test/15_refund_stock_test.dart -d windows
//
// ── The claim this exists to hold down ──────────────────────────────────────
//
// The 2026-09-09 trigger audit concluded that `ProcessRefundCommand`'s explicit
// reversal block is the ONLY thing moving stock on a refund. That conclusion is
// correct, and it rests entirely on `sys.triggers` holding no trigger on
// `DocumentItem` or `Stock` — which was true when somebody ran the query.
//
// 🚨 Nothing enforces it. Add a stock trigger on `DocumentItem` — one hand-run
// `trg_*.sql` away on any live database — and every refund returns stock TWICE:
// once from the trigger, once from the explicit block. Neither half errors. The
// shop simply grows inventory it never bought, and the first sign is a stock
// count that will not reconcile weeks later.
//
// So the assertion is not "stock came back". It is that stock came back
// **exactly once** — `after == before`, never `before + 1`.
//
// `Startup/TriggerReconciliation.cs` catches the DECLARATION drifting at boot.
// This catches the CONSEQUENCE, which is the part a customer would feel.
//
// ── Its sibling ─────────────────────────────────────────────────────────────
//
// `06_make_sale_retail` covers the other direction through
// `verifySaleChildRowsOnServer`: a sale's lines and payments reaching SQL Server
// at all, which is what an OUTPUT-clause refusal (error 334) would break on the
// two tables carrying PHANTOM trigger declarations.
//
// ── 🚨 It sells and refunds its OWN sale ────────────────────────────────────
//
// Not a document from an earlier test. A refund is not repeatable — the second
// attempt is refused with "already refunded" — so a test that reused a fixed
// receipt would pass once and fail every re-run for a reason that looks like a
// broken refund rather than a spent one.
//
// ── What it leaves behind ───────────────────────────────────────────────────
//
// A sale and its refund, and stock back where it started. That is the point of
// the shape: the company is not drained a unit per run.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/database/database_provider.dart';

import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/make_sale_helper.dart';
import 'helpers/open_register_helper.dart';
import 'helpers/record_catalog_helper.dart';
import 'helpers/refund_helper.dart';
import 'helpers/retail_mode_helper.dart';
import 'helpers/setup_stock_helper.dart';
import 'helpers/verify_sale_helper.dart';
import 'support/e2e_support.dart';

/// How close two stock figures must be to count as the same figure.
///
/// Stock travels through a `decimal` in SQL Server and a `double` here, and a
/// weighed product is held to three decimals — so this is below the smallest
/// unit any of them expresses, not a fudge for arithmetic that is wrong.
const double _stockTolerance = 0.0005;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('refund_stock', (tester) async {
    final ctx = E2EContext();

    // 🚨 A product that actually TAKES stock. A service is skipped by the
    // inventory logic entirely (CLAUDE.md), so selling one and then asserting
    // the stock moved would fail against a perfectly correct app.
    final catalogue = await loadE2ECatalog();
    final product = catalogue.stockable.firstWhere(
      (p) => !p.isToWeigh,
      orElse: () => throw TestFailure(
        'The recorded catalogue holds nothing that takes stock in whole units. '
        'Run 03_setup_catalog and 04_setup_stock first.',
      ),
    );
    step('Watching stock for "${product.name}"');

    await loginToCompany(tester, ctx);
    await configureRetailMode(tester, ctx);
    await ensureRegisterOpen(tester, ctx);
    await ensureTablelessAllowed(tester, ctx);

    // ── 1 · What the server holds before anything happens ─────────────────────
    final productId = await _productIdOf(ctx, product.name);
    final before = await serverStockOf(ctx, productId);
    step('Stock before: $before');

    // ── 2 · Sell one ──────────────────────────────────────────────────────────
    final sale = await makeSale(tester, ctx, productName: product.name);
    final doc = await verifySaleBanked(tester, ctx, sale);
    await syncNow(tester, ctx.l);
    await verifySaleOnServer(tester, ctx, sale, doc);

    final synced = await _serverNumberOf(ctx, doc.localId);

    // 🚨 Asserted BEFORE the refund, because it is a real claim of its own
    // (R40) and because a refund assertion means nothing if the sale never
    // moved stock in the first place — `after == before` would then be trivially
    // true and the test would pass while proving nothing.
    final afterSale = await serverStockOf(ctx, productId);
    expect(
      afterSale,
      closeTo(before - sale.quantity, _stockTolerance),
      reason: 'Selling ${sale.quantity} of "${product.name}" should leave '
          '${before - sale.quantity} on the server, not $afterSale. If nothing '
          'moved, the sale is not deducting stock at all.',
    );
    step('Stock after the sale: $afterSale');

    // ── 3 · Refund it ─────────────────────────────────────────────────────────
    await refundSale(tester, ctx, documentNumber: synced);
    await syncNow(tester, ctx.l);

    // ── 4 · Back to exactly where it started ──────────────────────────────────
    //
    // 🚨 `closeTo(before)` and NOT `greaterThan(afterSale)`. The looser
    // assertion passes on a double reversal, which is the failure this whole
    // test exists for — and a double reversal looks like a working refund from
    // every screen in the app.
    final afterRefund = await _settledStock(
      tester,
      ctx,
      productId: productId,
      expected: before,
    );

    expect(
      afterRefund,
      closeTo(before, _stockTolerance),
      reason: afterRefund > before + _stockTolerance
          ? 'Stock came back TWICE: started at $before, ended at $afterRefund '
              'after selling and refunding ${sale.quantity}.\n'
              '  Something other than ProcessRefundCommand is also returning '
              'stock — check sys.triggers on DocumentItem and Stock. The boot '
              'log from TriggerReconciliation will name it.'
          : 'Stock did not come back: started at $before, ended at '
              '$afterRefund. The explicit reversal in ProcessRefundCommand is '
              'the only thing that returns it, so it did not run.',
    );

    step('refund_stock PASSED — $before → $afterSale → $afterRefund '
        '(returned exactly once)');
  });
}

/// The server-side product id for [name], from the catalogue the till holds.
Future<int> _productIdOf(E2EContext ctx, String name) async {
  final db = ctx.container.read(appDatabaseProvider);
  final rows = await (db.select(db.productsTable)
        ..where((t) => t.companyId.equals(ctx.company.companyId)))
      .get();

  final match = rows.where((p) => p.name == name && p.id > 0);
  if (match.isEmpty) {
    throw TestFailure(
      '"$name" has no server-issued id on this terminal. A product still '
      'carrying a negative temp id has never synced, so the server holds no '
      'stock for it.',
    );
  }
  return match.first.id;
}

/// The document number the SERVER knows this sale by.
Future<String> _serverNumberOf(E2EContext ctx, String localId) async {
  final db = ctx.container.read(appDatabaseProvider);
  final row = await db.getDocumentByLocalId(localId);
  final number = row?.number;
  if (number == null || number.isEmpty) {
    throw TestFailure('The sale has no document number to look up.');
  }
  return number;
}

/// Waits for the server's stock to settle, then returns it.
///
/// 🚨 The refund is processed server-side and this test reads the server, so
/// there is no local row to wait on — but the request still has to land. Polling
/// until it reaches [expected] (or the wait runs out) means a SLOW server fails
/// on the real assertion below with real numbers, rather than here on a timeout
/// that says nothing about what the stock actually became.
Future<double> _settledStock(
  WidgetTester tester,
  E2EContext ctx, {
  required int productId,
  required double expected,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  var latest = await serverStockOf(ctx, productId);

  while (DateTime.now().isBefore(deadline)) {
    if ((latest - expected).abs() <= _stockTolerance) return latest;
    await pumpFor(tester, const Duration(seconds: 2));
    latest = await serverStockOf(ctx, productId);
  }
  return latest;
}
