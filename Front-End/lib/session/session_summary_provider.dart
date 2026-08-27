import 'package:drift/drift.dart' show OrderingTerm, leftOuterJoin;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/cash/cash_movement_kind.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/session/session_reconciliation.dart';
import 'package:pos_app/settings/device_identity.dart';

/// Company setting: the cash difference a cashier may close through alone.
const String kMaxCashDifferenceSetting = 'PosSession.MaxCashDifference';

/// Company setting: which payment methods come out of the cash drawer.
/// **Authoritative when set** — nothing is inferred.
const String kCashPaymentTypeIdsSetting = 'PosSession.CashPaymentTypeIds';

/// Reconciliation for ONE session — live, closing, or long closed — by localId.
///
/// 🚨 Mirrors `PosSessionService.BuildSummaryAsync`. The server stays the
/// authority — it recomputes on close and its number is what gets stored — but
/// a register with no connectivity still has to be able to see what it should
/// be holding, so the arithmetic exists on both sides against one formula.
///
/// 🚨 Keyed by the session rather than by "whatever this register is running"
/// because the detail screen has to render a CLOSED session too: a drawer that
/// was shut yesterday still owes the operator the full picture of what was in
/// it. A provider that only ever looked at the live row is exactly why that
/// screen went blank the moment the session closed.
final sessionSummaryProvider =
    StreamProvider.family<SessionReconciliation?, String>(
        (ref, sessionLocalId) async* {
  final db = ref.watch(appDatabaseProvider);
  final settings = ref.watch(appSettingsProvider);
  final types = ref.watch(allPaymentTypesProvider).value ?? const [];

  // Re-emit whenever anything the figures depend on changes — `shifts` too, so
  // the counted drawer and the closing stamps appear the instant they land.
  await for (final _ in db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.paymentsTable,
          db.startingCashTable,
          db.posOrdersTable,
          db.shiftsTable,
        },
      )
      .watch()) {
    final session = await (db.select(db.shiftsTable)
          ..where((t) => t.localId.equals(sessionLocalId)))
        .getSingleOrNull();
    yield session == null
        ? null
        : await _buildSummary(db, session, settings, types);
  }
});

/// Live reconciliation for the session THIS register is running, if any.
final activeSessionSummaryProvider =
    Provider<AsyncValue<SessionReconciliation?>>((ref) {
  final session = ref.watch(activeSessionRowProvider).value;
  if (session == null) return const AsyncValue.data(null);
  return ref.watch(sessionSummaryProvider(session.localId));
});

/// Every cash in / out booked against a session, newest first. The detail
/// screen lists them because "Cash In / Out + 0.00" answers a different
/// question from "who took 200 out of the drawer at 18:40, and why".
final sessionCashMovementsProvider =
    StreamProvider.family<List<StartingCashTableData>, String>(
        (ref, sessionLocalId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.startingCashTable)
        ..where((t) => t.sessionLocalId.equals(sessionLocalId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();
});

/// The SERVER's reconciliation for a session, by its server id.
///
/// 🚨 The only way to show real figures for a session this terminal did not
/// run. Another register's orders and payments were never written to this
/// device's Drift, so the local arithmetic would honestly report "0 orders,
/// 0.00 taken" for a till that sold all day — a wrong number stated
/// confidently, which is worse than no number.
///
/// Null when offline or before the session has a server id. The caller falls
/// back to the local rows, which is the right answer for its OWN sessions
/// anyway: those are complete on this device even with the network down.
final remoteSessionSummaryProvider =
    FutureProvider.family<SessionReconciliation?, int>((ref, serverId) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return null;

  try {
    final res = await createDio().get<Map<String, dynamic>>(
      '/PosSession/Summary',
      queryParameters: {'companyId': companyId, 'sessionId': serverId},
    );
    final data = res.data;
    if (data == null) return null;

    double num0(dynamic v) => (v as num?)?.toDouble() ?? 0;

    return SessionReconciliation(
      openingCash: num0(data['openingCash']),
      cashPayments: num0(data['cashPayments']),
      cashIn: num0(data['cashIn']),
      cashOut: num0(data['cashOut']),
      documentCount: (data['orderCount'] as num?)?.toInt() ?? 0,
      methods: ((data['methods'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((m) => SessionMethodTotal(
                paymentTypeId: (m['paymentTypeId'] as num?)?.toInt() ?? 0,
                paymentTypeName: (m['paymentTypeName'] as String?) ?? '',
                isCash: m['isCash'] as bool? ?? false,
                expected: num0(m['expected']),
                counted: (m['counted'] as num?)?.toDouble(),
              ))
          .toList(),
      maxCashDifference: num0(data['maxCashDifference']),
      cashMethodsConfigured: data['cashMethodsConfigured'] as bool? ?? true,
      recordedExpectedCash: (data['expectedCash'] as num?)?.toDouble(),
    );
  } catch (_) {
    // Offline, or the server has never heard of this session. Not an error the
    // operator can act on — the screen says so and shows what it has.
    return null;
  }
});

/// The active session row, split out so the summary can depend on it without
/// re-running the whole device lookup.
final activeSessionRowProvider = StreamProvider<ShiftsTableData?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  final uid = ref.watch(deviceUidProvider).value;
  if (companyId == null || uid == null) return Stream.value(null);

  return (db.select(db.shiftsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.posDeviceUid.equals(uid))
        ..where((t) => t.status.isIn(PosSessionStatus.live))
        ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
        ..limit(1))
      .watchSingleOrNull();
});

/// One payment taken during a session, with the document it settles.
///
/// The pair travels together because neither half answers the question on its
/// own: "42.00 by card" is meaningless without knowing which sale, and the
/// document alone does not say how it was paid or how many times.
class SessionPaymentEntry {
  const SessionPaymentEntry({
    required this.payment,
    required this.paymentTypeName,
    required this.isCash,
    this.document,
  });

  final PaymentsTableData payment;
  final String paymentTypeName;
  final bool isCash;

  /// Null only for a payment whose document is not on this device — possible
  /// for a pulled session, never for one this register rang up.
  final DocumentsTableData? document;

  String get documentNumber =>
      (document?.number ?? '').trim().isNotEmpty ? document!.number!.trim() : '—';

  /// True for a refund: money went back OUT of the drawer.
  bool get isRefund => payment.amount < 0;
}

/// Every payment booked against a session, newest first.
///
/// 🚨 Keyed on the PAYMENT's session, not its document's. Settling yesterday's
/// unpaid invoice puts cash in TODAY's drawer, and today's drawer is what gets
/// counted — so the money follows the session that took it.
final sessionPaymentsProvider =
    StreamProvider.family<List<SessionPaymentEntry>, String>(
        (ref, sessionLocalId) {
  final db = ref.watch(appDatabaseProvider);
  final settings = ref.watch(appSettingsProvider);
  final types = ref.watch(allPaymentTypesProvider).value ?? const [];
  final cashIds = resolveCashPaymentTypeIds(settings, types);

  final query = db.select(db.paymentsTable).join([
    leftOuterJoin(db.documentsTable,
        db.documentsTable.localId.equalsExp(db.paymentsTable.documentId)),
  ])
    ..where(db.paymentsTable.sessionLocalId.equals(sessionLocalId))
    ..orderBy([OrderingTerm.desc(db.paymentsTable.date)]);

  return query.watch().map((rows) => rows.map((r) {
        final payment = r.readTable(db.paymentsTable);
        String nameFor(int id) {
          for (final t in types) {
            if (t.id == id) return t.name;
          }
          return '#$id';
        }

        return SessionPaymentEntry(
          payment: payment,
          paymentTypeName: nameFor(payment.paymentTypeId),
          isCash: cashIds.contains(payment.paymentTypeId),
          document: r.readTableOrNull(db.documentsTable),
        );
      }).toList());
});

/// One document banked during a session, with the customer it was rung up for.
class SessionDocumentEntry {
  const SessionDocumentEntry({required this.document, this.customerName});

  final DocumentsTableData document;

  /// Null for a walk-in sale, or when the customer row has not reached this
  /// device — cosmetic either way, so the row still renders without it.
  final String? customerName;

  /// Refunds are their own document type. Money went back OUT, so the row must
  /// not read as another sale.
  bool get isRefund => document.documentTypeId == kRefundDocumentTypeId;

  bool get isUnpaid => document.paidStatus == 0;

  /// No server number assigned yet — the list says so rather than showing a
  /// blank where a number belongs.
  bool get isPendingSync =>
      document.syncStatus == 'pending' || document.syncStatus == 'pending_create';
}

/// `document_type_id` for a refund.
const int kRefundDocumentTypeId = 4;

/// Every document a session banked, newest first.
///
/// 🚨 DOCUMENTS, not pos_orders — the same set the "Documents" figure on the
/// overview counts. Checkout consumes the order row and produces the document,
/// so counting orders counts only what is still unpaid.
///
/// Keyed on the DOCUMENT's session, unlike [sessionPaymentsProvider] which is
/// keyed on the payment's: a sale belongs to the session that rang it up, while
/// the money belongs to the session whose drawer it landed in. Settling an old
/// invoice today puts cash in today's session and leaves the document in the
/// one that issued it — and both statements are what their tab is there to
/// make.
final sessionDocumentsProvider =
    StreamProvider.family<List<SessionDocumentEntry>, String>(
        (ref, sessionLocalId) {
  final db = ref.watch(appDatabaseProvider);

  // Joined rather than looked up per row: a busy session is hundreds of
  // documents, and an N+1 on every rebuild would be felt on a tablet.
  final query = db.select(db.documentsTable).join([
    leftOuterJoin(db.customersTable,
        db.customersTable.id.equalsExp(db.documentsTable.customerId)),
  ])
    ..where(db.documentsTable.sessionLocalId.equals(sessionLocalId))
    ..orderBy([OrderingTerm.desc(db.documentsTable.date)]);

  return query.watch().map((rows) => rows
      .map((r) => SessionDocumentEntry(
            document: r.readTable(db.documentsTable),
            customerName: r.readTableOrNull(db.customersTable)?.name,
          ))
      .toList());
});

/// Attaches sales rung up BEFORE this build to the session they belong to.
///
/// 🚨 A repair, not a feature. `sessionLocalId` is stamped at checkout now, but
/// every sale banked before that shipped carries NULL — the session that took
/// them would report an empty till forever. Matching is deliberately narrow:
/// same company, no session yet, timestamp inside the session's own window, and
/// a document number carrying THIS register's prefix, so a sale pulled from
/// another till can never be absorbed into this one's drawer.
///
/// Own sessions only. A pulled session's takings come from the server, which
/// has the authoritative answer for a register this device never was.
final sessionLinkRepairProvider =
    FutureProvider.family<int, String>((ref, sessionLocalId) async {
  final db = ref.watch(appDatabaseProvider);
  final session = await (db.select(db.shiftsTable)
        ..where((t) => t.localId.equals(sessionLocalId)))
      .getSingleOrNull();
  if (session == null || session.posDeviceUid == null) return 0;

  final prefix = (session.posDeviceName ?? await getDeviceName()).trim();
  if (prefix.isEmpty) return 0; // No prefix, no way to tell the tills apart.

  return db.attachOrphanSalesToSession(
    sessionLocalId: sessionLocalId,
    companyId: session.companyId,
    from: session.openedAt,
    to: session.closedAt ?? DateTime.now().toUtc(),
    numberPrefix: prefix,
  );
});

Future<SessionReconciliation> _buildSummary(
  AppDatabase db,
  ShiftsTableData session,
  Map<String, String> settings,
  List<dynamic> paymentTypes,
) async {
  final cashIds = resolveCashPaymentTypeIds(settings, paymentTypes);

  final payments = await (db.select(db.paymentsTable)
        ..where((t) => t.sessionLocalId.equals(session.localId)))
      .get();

  final byType = <int, double>{};
  for (final p in payments) {
    byType[p.paymentTypeId] = (byType[p.paymentTypeId] ?? 0) + p.amount;
  }

  final movements = await (db.select(db.startingCashTable)
        ..where((t) => t.sessionLocalId.equals(session.localId)))
      .get();
  final cashIn = movements
      .where((m) => m.type == CashMovementKind.cashIn)
      .fold<double>(0, (s, m) => s + m.amount);
  final cashOut = movements
      .where((m) => m.type == CashMovementKind.cashOut)
      .fold<double>(0, (s, m) => s + m.amount);

  // 🚨 DOCUMENTS, not pos_orders. Checkout consumes the order row and produces
  // a document with payments — counting orders counts what is still unpaid,
  // which is why a session that sold all day reported "0".
  final documents = await (db.select(db.documentsTable)
        ..where((t) => t.sessionLocalId.equals(session.localId)))
      .get();

  String nameFor(int id) {
    for (final t in paymentTypes) {
      if (t.id == id) return t.name as String;
    }
    return '#$id';
  }

  final methods = byType.entries
      .map((e) => SessionMethodTotal(
            paymentTypeId: e.key,
            paymentTypeName: nameFor(e.key),
            isCash: cashIds.contains(e.key),
            expected: e.value,
          ))
      .toList()
    ..sort((a, b) {
      if (a.isCash != b.isCash) return a.isCash ? -1 : 1;
      return a.paymentTypeName.compareTo(b.paymentTypeName);
    });

  return SessionReconciliation(
    openingCash: session.startingCash,
    cashPayments:
        methods.where((m) => m.isCash).fold<double>(0, (s, m) => s + m.expected),
    cashIn: cashIn,
    cashOut: cashOut,
    documentCount: documents.length,
    methods: methods,
    countedCash: session.actualEndingCash,
    // Once CLOSED, the stored figure is the one that was signed off and the
    // one the Z-report was built on — never recompute past that point.
    recordedExpectedCash:
        session.status == PosSessionStatus.closed ? session.expectedCash : null,
    maxCashDifference: _maxDifference(settings),
    cashMethodsConfigured:
        (settings[kCashPaymentTypeIdsSetting] ?? '').trim().isNotEmpty,
  );
}

double _maxDifference(Map<String, String> settings) =>
    double.tryParse(settings[kMaxCashDifferenceSetting] ?? '') ?? 10;

/// Which payment methods come out of the cash drawer.
///
/// 🚨 `PosSession.CashPaymentTypeIds` is AUTHORITATIVE — when it is set, it is
/// used verbatim so a method the company has not listed (Credit, a voucher, a
/// wallet) can never be counted as drawer cash. The `isChangeAllowed` inference
/// below is a development/legacy fallback for an unconfigured company only; it
/// exists so the screen shows something plausible rather than an expected cash
/// of just the opening float. Same precedence as the server.
Set<int> resolveCashPaymentTypeIds(
  Map<String, String> settings,
  List<dynamic> paymentTypes,
) {
  final raw = (settings[kCashPaymentTypeIdsSetting] ?? '').trim();
  if (raw.isNotEmpty) {
    final ids = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((i) => i > 0)
        .toSet();
    if (ids.isNotEmpty) return ids;
  }
  return paymentTypes
      .where((t) => t.isChangeAllowed == true)
      .map<int>((t) => t.id as int)
      .toSet();
}

/// Sales this device has NOT pushed yet, for the session it belongs to.
///
/// 🚨 Only the device can answer this, and it is the reason a close must be
/// gated locally: closing while these exist produces a Z-report missing sales
/// that really happened. Requirement §14.
final unsyncedSalesCountProvider =
    StreamProvider.family<int, String>((ref, sessionLocalId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.posOrdersTable)
    ..where((t) => t.sessionLocalId.equals(sessionLocalId))
    ..where((t) => t.syncStatus.equals('pending'))
    ..where((t) => t.status.equals(1));
  return query.watch().map((rows) => rows.length);
});

/// Orders still parked on tables for this session.
final openOrdersCountProvider =
    StreamProvider.family<int, String>((ref, sessionLocalId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.posOrdersTable)
    ..where((t) => t.sessionLocalId.equals(sessionLocalId))
    ..where((t) => t.status.equals(0));
  return query.watch().map((rows) => rows.length);
});

/// Everything stopping a normal close, from the device's point of view.
final closeBlockersProvider =
    Provider.family<List<SessionCloseBlocker>, String>((ref, sessionLocalId) {
  final open = ref.watch(openOrdersCountProvider(sessionLocalId)).value ?? 0;
  final unsynced =
      ref.watch(unsyncedSalesCountProvider(sessionLocalId)).value ?? 0;

  return [
    if (open > 0) SessionCloseBlocker(SessionCloseBlockerKind.openOrders, open),
    if (unsynced > 0)
      SessionCloseBlocker(SessionCloseBlockerKind.unsyncedSales, unsynced),
  ];
});
