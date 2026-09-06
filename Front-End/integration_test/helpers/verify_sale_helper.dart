/// `verifySaleBanked` — proves a sale landed in local SQLite AND on the server.
///
/// ```dart
/// final sale = await makeSale(tester, ctx);
/// final doc  = await verifySaleBanked(tester, ctx, sale);   // local
/// await syncNow(tester, ctx.l);
/// await verifySaleOnServer(tester, ctx, sale, doc);         // server
/// ```
///
/// Split into two calls because a sync has to happen between them, and hiding
/// that inside one helper would hide the only step that makes the second claim
/// mean anything.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';
import 'make_sale_helper.dart';

/// How close two money figures must be to count as the same figure.
///
/// Not a fudge factor for arithmetic the app gets wrong — half a centime is
/// below the smallest unit any of these currencies has. It exists because the
/// same total travels through a `double` in Dart, a `REAL` in SQLite and a
/// `decimal` in SQL Server, and the last leg comes back through JSON.
const double kMoneyTolerance = 0.005;

/// Asserts the sale was written to local SQLite, and returns its document row.
///
/// 🚨 Asserted on the CONTENT, never on `syncStatus == 'pending'`. Checkout
/// fires a background sync on its way out, so the row can legitimately be
/// `synced` before this line runs — a test demanding "pending" here would fail
/// on a FAST network, for the best possible reason.
Future<DocumentsTableData> verifySaleBanked(
  WidgetTester tester,
  E2EContext ctx,
  E2ESale sale,
) async {
  final db = ctx.container.read(appDatabaseProvider);

  // 🚨 Identified as "the row that was not here a moment ago", not as "the
  // newest row". The local database also holds documents pulled from the SERVER
  // and from OTHER tills, so newest is a guess that goes wrong exactly when a
  // colleague rings something up mid-run.
  late DocumentsTableData doc;
  await waitUntil(
    tester,
    () async {
      final fresh = (await db.getDocuments(companyId: ctx.company.companyId))
          .where((d) => !sale.documentsBefore.contains(d.localId))
          .toList();
      if (fresh.isEmpty) return false;
      doc = fresh.single;
      return true;
    },
    describe: 'the sale is written to local SQLite',
    timeout: const Duration(seconds: 60),
  );

  expect(doc.companyId, ctx.company.companyId);
  expect(doc.userId, sale.userId);
  expect(
    doc.total,
    closeTo(sale.total, kMoneyTolerance),
    reason: 'The banked document does not carry the total the cashier saw.',
  );
  expect(
    doc.number,
    isNotNull,
    reason: 'A sale is numbered locally at checkout so it is refundable '
        'offline — see nextDocumentNumber.',
  );
  expect(doc.number, isNotEmpty);

  // The drawer has to own the sale, or the session screen reports a till that
  // sold all day as "0 documents / 0.00 taken".
  //
  // Conditional because a null session is LEGITIMATE rather than a failure:
  // `PosSession.RequireOpenSession` can be off, in which case there is no drawer
  // to attach to and the sale banks unattached by design. Asserting an id that
  // was never supposed to exist would fail a correctly-working till.
  if (sale.sessionLocalId != null) {
    expect(
      doc.sessionLocalId,
      sale.sessionLocalId,
      reason: 'The sale was not attached to the open session.',
    );
  } else {
    step('No open session on this register — sale banked unattached');
  }

  final items = await db.getDocumentItems(doc.localId);
  expect(items.length, 1);
  expect(items.single.productId, sale.productId);
  expect(items.single.quantity, closeTo(sale.quantity, kMoneyTolerance));
  expect(items.single.unitPrice, closeTo(sale.unitPrice, kMoneyTolerance));

  final payments = await db.getPayments(doc.localId);
  expect(payments.length, 1);
  expect(payments.single.paymentTypeId, sale.paymentTypeId);
  // Capped at the total: the change is not money the shop took.
  expect(payments.single.amount, closeTo(sale.total, kMoneyTolerance));

  step('Saved locally — document ${doc.number} for ${doc.total}');
  return doc;
}

/// Asserts the server has the same sale, with the same money and the same number.
///
/// Two halves, and both are needed. First the local side of the handshake —
/// BatchSync stamps the server's `Document.Id` onto this row and flips it to
/// `synced`. Then the server's own answer, fetched over the same authenticated
/// Dio the app uses: a local row claiming `synced` is the APP's word for it;
/// `/Document/GetAll` is the server's.
///
/// 🚨 The document NUMBER is compared, not just the total. The device issues
/// that number offline and BatchSync keeps it rather than generating its own —
/// so this is what proves a receipt in the customer's hand matches the record,
/// even for a sale rung up with no network.
Future<void> verifySaleOnServer(
  WidgetTester tester,
  E2EContext ctx,
  E2ESale sale,
  DocumentsTableData doc,
) async {
  final db = ctx.container.read(appDatabaseProvider);

  await waitUntil(
    tester,
    () async {
      final row = await db.getDocumentByLocalId(doc.localId);
      return row?.serverId != null && row?.syncStatus == 'synced';
    },
    describe: 'the sale is accepted by the server',
    timeout: const Duration(seconds: 180),
  );

  final synced = (await db.getDocumentByLocalId(doc.localId))!;
  step('Server accepted it as document ${synced.serverId}');

  final remote = await ApiClient().getAllDocuments(ctx.company.companyId);
  final match = remote
      .cast<Map<String, dynamic>>()
      .where((d) => d['id'] == synced.serverId)
      .toList();

  expect(
    match,
    hasLength(1),
    reason: 'Document ${synced.serverId} is not in /Document/GetAll for '
        'company ${ctx.company.companyId}.',
  );

  final remoteDoc = match.single;
  expect(
    (remoteDoc['total'] as num).toDouble(),
    closeTo(sale.total, kMoneyTolerance),
    reason: 'The server banked a different total than the cashier was shown.',
  );
  expect(
    remoteDoc['number'],
    synced.number,
    reason: 'The server renumbered the sale — a receipt already in the '
        "customer's hand would no longer match the record.",
  );

  ctx.record(E2EArtifact(
    table: 'Document',
    name: synced.number ?? '',
    extra: {
      'ServerId': synced.serverId,
      'Total': sale.total,
      'Product': sale.productName,
    },
  ));

  step('Sale verified — local ${synced.number} = server ${synced.serverId} '
      'for ${sale.total}');
}
