import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/reports/z_report_model.dart';

/// Offline-first Z-report history, read from the local Drift `z_reports` table.
/// Rows are written at Close-Register time (with locally-computed totals) and
/// pushed to /ZReports/Generate by SyncManager; no network round-trip to read.
final allZReportsProvider =
    FutureProvider.autoDispose<List<ZReportModel>>((ref) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final db = ref.watch(appDatabaseProvider);
  final rows = await db.getZReportHistory(companyId);

  return rows.map((r) {
    final summaries = <ZReportPaymentSummaryModel>[];
    try {
      final decoded = jsonDecode(r.paymentBreakdownJson);
      if (decoded is List) {
        for (final e in decoded.cast<Map<String, dynamic>>()) {
          summaries.add(ZReportPaymentSummaryModel(
            id: 0,
            zReportId: r.serverId ?? 0,
            paymentTypeId: (e['paymentTypeId'] as num?)?.toInt() ?? 0,
            paymentTypeName: e['paymentTypeName'] as String?,
            totalAmount: (e['totalAmount'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
    } catch (_) {/* legacy '{}' or malformed — no breakdown */}

    return ZReportModel(
      id: r.serverId ?? 0,
      companyId: r.companyId,
      number: r.serverId ?? 0,
      dateCreated: r.closedAt,
      fromDocumentId: 0,
      toDocumentId: 0,
      totalSales: r.totalSales,
      totalReturns: 0,
      discountsGranted: 0,
      taxableTotal: 0,
      totalTax: 0,
      grandTotal: r.totalSales,
      totalCashIn: r.totalCashIn,
      totalCashOut: r.totalCashOut,
      paymentSummaries: summaries,
    );
  }).toList();
});
