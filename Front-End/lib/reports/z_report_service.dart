/// Builds, persists and finalises a Z-report — the one implementation behind
/// both the End-of-Day screen and closing a POS session.
///
/// ## Why this is a service and not two screens
///
/// The Z-report used to exist only inside `EndOfDayScreen._closeRegister`:
/// ~80 lines that aggregated, numbered, inserted the row, stamped the payments,
/// finalised the cash movements and kicked a sync — all in a widget. Closing a
/// register did none of it; `closeSession` marked the shift row closed and left
/// the report to the server's `PosSessionService.GenerateForSessionAsync`, which
/// means an offline till closed its drawer and had **no slip to print and
/// nothing to show** until it next reached the network.
///
/// Both paths now call [generate]. They differ in exactly one thing — the
/// **scope** — and everything else is shared, which is the point: two copies of
/// "what a Z-report is" would be free to disagree while both printed confident
/// numbers.
///
/// ## Scope
///
/// * [ZReportScope.company] — every payment no Z-report has claimed yet, across
///   the company. What End-of-Day has always reported on.
/// * [ZReportScope.session] — the payments, documents and cash movements
///   carrying one `sessionLocalId`. What closing a register reports on.
///
/// 🚨 Both scopes **stamp what they reported**. A session close that did not
/// stamp would leave its sales in the company-wide unreported set, and the next
/// End-of-Day would count the same money a second time.
///
/// ## Offline-first
///
/// Everything is computed and persisted locally, so the slip prints instantly
/// with no server round-trip. `SyncManager.pushPendingZReports` later sends the
/// row to `/ZReports/Generate` and overwrites the device-local number with the
/// server's authoritative one. There is no `pullZReports`: this row is the only
/// copy the app will ever read, so every figure has to be computed here rather
/// than left for a pull to fill in.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:pos_app/cash/cash_movement_kind.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/reports/z_report_model.dart';

/// Which sales a Z-report covers.
enum ZReportScope {
  /// Everything unreported across the company (End of Day).
  company,

  /// One register's session (Close Register).
  session,
}

/// Generates Z-reports. Stateless; the database is passed in so the caller
/// controls the transaction boundary and tests need no Riverpod container.
abstract final class ZReportService {
  /// Builds the report for a scope, persists it, and finalises what it covered.
  ///
  /// [sessionLocalId] is required for [ZReportScope.session] and ignored
  /// otherwise. Returns the report as it should be displayed and printed right
  /// now — with the **device-local** number, which is what identifies the slip
  /// in the cashier's hand until the push assigns the server's.
  ///
  /// Returns null when the scope holds no payments at all: there is nothing to
  /// report, and writing an empty row would burn a Z-report number and make the
  /// sequence lie about how many times the register was closed.
  static Future<ZReportModel?> generate({
    required AppDatabase db,
    required int companyId,
    required int userId,
    required ZReportScope scope,
    String? sessionLocalId,
  }) async {
    assert(
      scope != ZReportScope.session || sessionLocalId != null,
      'A session-scoped Z-report needs the session it reports on.',
    );

    final now = DateTime.now().toUtc();

    // 🚨 Aggregate BEFORE stamping anything. The stamp is what empties the set
    // these figures are computed from, and nothing records which payments
    // belonged to which report — once stamped, the scope is unrecoverable.
    final totals = scope == ZReportScope.session
        ? await db.aggregateSessionForZReport(sessionLocalId!)
        : await db.aggregateUnreportedForZReport(companyId);

    final payments = scope == ZReportScope.session
        ? await db.getUnreportedSessionPayments(sessionLocalId!)
        : await db.getUnreportedPayments(companyId);

    if (payments.isEmpty) return null;

    final typeRows = await db.select(db.paymentTypesTable).get();
    final typeNames = {for (final t in typeRows) t.id: t.name};

    final byType = <int, ({String name, double amount})>{};
    for (final p in payments) {
      final current = byType[p.paymentTypeId];
      byType[p.paymentTypeId] = (
        // Persisted into paymentBreakdownJson, so it stays English like every
        // other value written to the DB — only the on-screen copy is translated.
        name: current?.name ?? typeNames[p.paymentTypeId] ?? 'Unknown',
        amount: (current?.amount ?? 0) + p.amount,
      );
    }

    final cashRows = scope == ZReportScope.session
        ? await db.getActiveSessionStartingCash(sessionLocalId!)
        : await db.getActiveStartingCash(companyId);
    double totalCashIn = 0;
    double totalCashOut = 0;
    for (final c in cashRows) {
      // 🚨 Named kinds, never `else`. An `opening` row is in this list and is
      // NOT drawer movement — the session's startingCash already carries it, so
      // folding it into either total counts the float twice.
      if (c.type == CashMovementKind.cashIn) {
        totalCashIn += c.amount;
      } else if (c.type == CashMovementKind.cashOut) {
        totalCashOut += c.amount;
      }
    }

    final summaries = byType.entries
        .map((e) => ZReportPaymentSummaryModel(
              id: 0,
              zReportId: 0,
              paymentTypeId: e.key,
              paymentTypeName: e.value.name,
              totalAmount: e.value.amount,
            ))
        .toList();

    final breakdownJson = jsonEncode(summaries
        .map((s) => {
              'paymentTypeId': s.paymentTypeId,
              'paymentTypeName': s.paymentTypeName,
              'totalAmount': s.totalAmount,
            })
        .toList());

    // Device-local number so the slip printed right now is identified; the push
    // overwrites it with the server's authoritative one.
    final number = await db.nextLocalZReportNumber(companyId);

    await db.insertOfflineZReport(
      ZReportsTableCompanion.insert(
        localId: '', // helper fills a UUID when blank
        companyId: companyId,
        userId: userId,
        totalSales: totals.totalSales,
        totalCashIn: totalCashIn,
        totalCashOut: totalCashOut,
        paymentBreakdownJson: breakdownJson,
        closedAt: now,
        number: Value(number),
        dateCreated: Value(now),
        documentCount: Value(totals.documentCount),
        fromDocumentNumber: Value(totals.fromDocumentNumber),
        toDocumentNumber: Value(totals.toDocumentNumber),
        totalReturns: Value(totals.totalReturns),
        discountsGranted: Value(totals.discountsGranted),
        taxableTotal: Value(totals.taxableTotal),
        totalTax: Value(totals.totalTax),
        grandTotal: Value(totals.grandTotal),
      ),
    );

    // Optimistic local finalisation: flag what was just reported so it drops
    // out of the "current shift" view immediately, and — the part that matters
    // — can never be reported on twice.
    if (scope == ZReportScope.session) {
      await db.assignSessionPaymentsToZReport(sessionLocalId!);
      await db.finalizeSessionStartingCash(sessionLocalId);
    } else {
      await db.assignUnreportedPaymentsToZReport(companyId);
      await db.optimisticallyFinalizeActiveStartingCash(companyId);
    }

    return ZReportModel(
      id: 0,
      companyId: companyId,
      number: number,
      dateCreated: now,
      fromDocumentId: 0,
      toDocumentId: 0,
      documentCount: totals.documentCount,
      fromDocumentNumber: totals.fromDocumentNumber,
      toDocumentNumber: totals.toDocumentNumber,
      totalSales: totals.totalSales,
      totalReturns: totals.totalReturns,
      discountsGranted: totals.discountsGranted,
      taxableTotal: totals.taxableTotal,
      totalTax: totals.totalTax,
      grandTotal: totals.grandTotal,
      totalCashIn: totalCashIn,
      totalCashOut: totalCashOut,
      paymentSummaries: summaries,
    );
  }

  /// The same figures [generate] would produce, **without writing anything**.
  ///
  /// Backs the "Print Z Report" button in the closing dialog: a cashier can
  /// take a slip of where the register stands at any point, and reading the
  /// drawer must never be the thing that closes it. Nothing is stamped, so the
  /// real close still reports on the full session.
  static Future<ZReportModel?> preview({
    required AppDatabase db,
    required int companyId,
    required String sessionLocalId,
  }) async {
    final totals = await db.aggregateSessionForZReport(sessionLocalId);
    final payments = await db.getUnreportedSessionPayments(sessionLocalId);
    if (payments.isEmpty) return null;

    final typeRows = await db.select(db.paymentTypesTable).get();
    final typeNames = {for (final t in typeRows) t.id: t.name};

    final byType = <int, double>{};
    for (final p in payments) {
      byType[p.paymentTypeId] = (byType[p.paymentTypeId] ?? 0) + p.amount;
    }

    final cashRows = await db.getActiveSessionStartingCash(sessionLocalId);
    double totalCashIn = 0;
    double totalCashOut = 0;
    for (final c in cashRows) {
      // 🚨 Named kinds, never `else`. An `opening` row is in this list and is
      // NOT drawer movement — the session's startingCash already carries it, so
      // folding it into either total counts the float twice.
      if (c.type == CashMovementKind.cashIn) {
        totalCashIn += c.amount;
      } else if (c.type == CashMovementKind.cashOut) {
        totalCashOut += c.amount;
      }
    }

    return ZReportModel(
      id: 0,
      companyId: companyId,
      // 0 marks this as a preview rather than a numbered report: the number
      // belongs to the sequence, and handing one out here would either burn it
      // or print a number the real close then reuses.
      number: 0,
      dateCreated: DateTime.now().toUtc(),
      fromDocumentId: 0,
      toDocumentId: 0,
      documentCount: totals.documentCount,
      fromDocumentNumber: totals.fromDocumentNumber,
      toDocumentNumber: totals.toDocumentNumber,
      totalSales: totals.totalSales,
      totalReturns: totals.totalReturns,
      discountsGranted: totals.discountsGranted,
      taxableTotal: totals.taxableTotal,
      totalTax: totals.totalTax,
      grandTotal: totals.grandTotal,
      totalCashIn: totalCashIn,
      totalCashOut: totalCashOut,
      paymentSummaries: byType.entries
          .map((e) => ZReportPaymentSummaryModel(
                id: 0,
                zReportId: 0,
                paymentTypeId: e.key,
                paymentTypeName: typeNames[e.key] ?? 'Unknown',
                totalAmount: e.value,
              ))
          .toList(),
    );
  }
}
