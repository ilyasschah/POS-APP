import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/cart/payment_model.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';

/// Offline-first payments for a document, keyed by its Drift local UUID.
/// Streams straight from local SQLite (source of truth) and, when online,
/// kicks a one-shot background refresh from the server so payments made on
/// other devices appear. Payment-type names are resolved from the local cache.
final localDocumentPaymentsProvider = StreamProvider.autoDispose
    .family<List<PaymentModel>, LocalPaymentsArgs>((ref, args) {
  final db = ref.watch(appDatabaseProvider);

  // Best-effort cache refresh — fire-and-forget, never blocks the stream.
  if (args.documentServerId != null) {
    refreshDocumentPaymentsFromServer(
      db,
      docLocalId: args.documentLocalId,
      documentServerId: args.documentServerId!,
      companyId: args.companyId,
    );
  }

  return db.watchPayments(args.documentLocalId).asyncMap((rows) async {
    final types = await db.select(db.paymentTypesTable).get();
    final typeNames = {for (final t in types) t.id: t.name};
    return rows
        .map((r) => PaymentModel(
              id: r.serverId ?? 0,
              localId: r.localId,
              documentId: args.documentServerId ?? 0,
              paymentTypeId: r.paymentTypeId,
              paymentTypeName: typeNames[r.paymentTypeId],
              amount: r.amount,
              date: r.date,
              userId: r.userId,
              zReportId: r.zReportId,
              syncStatus: r.syncStatus,
            ))
        .toList();
  });
});

/// Pulls /Payments/GetByDocumentId and reconciles the rows into local SQLite,
/// preserving any unsynced local edits. Swallows errors (offline is normal).
Future<void> refreshDocumentPaymentsFromServer(
  AppDatabase db, {
  required String docLocalId,
  required int documentServerId,
  required int companyId,
}) async {
  try {
    final dio = createDio();
    final response = await dio.get(
      '/Payments/GetByDocumentId',
      queryParameters: {'documentId': documentServerId, 'companyId': companyId},
    );
    final rows = (response.data as List).map((j) {
      final m = j as Map<String, dynamic>;
      final serverId = (m['id'] as num?)?.toInt();
      final paidDate = DateTime.tryParse(m['date']?.toString() ?? '') ??
          DateTime.now();
      return PaymentsTableCompanion(
        localId: Value('srvpay_$serverId'),
        serverId: Value(serverId),
        documentId: Value(docLocalId),
        paymentTypeId: Value((m['paymentTypeId'] as num?)?.toInt() ?? 0),
        amount: Value((m['amount'] as num?)?.toDouble() ?? 0.0),
        userId: Value((m['userId'] as num?)?.toInt() ?? 0),
        date: Value(paidDate),
        zReportId: Value((m['zReportId'] as num?)?.toInt()),
        // Were left null on pulled rows — populate from the server (companyId
        // falls back to the known company; dateCreated to the server's value or
        // the payment date).
        companyId: Value((m['companyId'] as num?)?.toInt() ?? companyId),
        dateCreated:
            Value(DateTime.tryParse(m['dateCreated']?.toString() ?? '') ??
                paidDate),
        syncStatus: const Value('synced'),
      );
    }).toList();
    await db.reconcileServerPayments(docLocalId, rows);
  } catch (e) {
    debugPrint('refreshDocumentPaymentsFromServer failed: $e');
  }
}

/// Family key for [localDocumentPaymentsProvider].
class LocalPaymentsArgs {
  final String documentLocalId;
  final int? documentServerId;
  final int companyId;

  const LocalPaymentsArgs({
    required this.documentLocalId,
    required this.documentServerId,
    required this.companyId,
  });

  @override
  bool operator ==(Object other) =>
      other is LocalPaymentsArgs &&
      other.documentLocalId == documentLocalId &&
      other.documentServerId == documentServerId &&
      other.companyId == companyId;

  @override
  int get hashCode =>
      Object.hash(documentLocalId, documentServerId, companyId);
}

/// Offline-first: payments not yet tied to a Z-report, read from local Drift.
/// Drives the End-of-Day "current shift" preview and the offline Z-report
/// aggregation — no network round-trip.
final unreportedPaymentsProvider =
    FutureProvider.autoDispose<List<PaymentModel>>((ref) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final db = ref.watch(appDatabaseProvider);
  final rows = await db.getUnreportedPayments(companyId);
  final types = await db.select(db.paymentTypesTable).get();
  final typeNames = {for (final t in types) t.id: t.name};

  return rows
      .map((r) => PaymentModel(
            id: r.serverId ?? 0,
            localId: r.localId,
            documentId: 0,
            paymentTypeId: r.paymentTypeId,
            paymentTypeName: typeNames[r.paymentTypeId],
            amount: r.amount,
            date: r.date,
            userId: r.userId,
            syncStatus: r.syncStatus,
          ))
      .toList();
});
