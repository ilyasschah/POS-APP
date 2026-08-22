// The link between a payment and the session whose drawer took it.
//
// `payments.sessionLocalId` is DEVICE knowledge: the server has no idea which
// register's session was open when the money was handed over, so nothing that
// rebuilds a payment from an API response can be allowed to drop it. When it
// is dropped the payment does not merely disappear from the session screen —
// it falls out of the session's takings, and the expected-cash figure the
// cashier is held to at closing silently shrinks by that amount.
//
// The bug this pins down: opening a document from the session's Payments tab
// refreshed that document's payments from the server, and the refresh wiped
// the local rows (which carried the link) in favour of server rows (which
// cannot). Going back showed an empty Payments tab and a smaller drawer.
import 'package:drift/drift.dart' show Value, InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 8, 22, 18);
  const docLocalId = 'doc-1';
  const sessionLocalId = 'sess-1';

  Future<void> seedDocument() => db.into(db.documentsTable).insert(
        DocumentsTableCompanion.insert(
          localId: docLocalId,
          companyId: 25,
          userId: 9,
          warehouseId: 1,
          date: now,
          lastModified: now,
          serverId: const Value(200),
          number: const Value('POS1-200-000025'),
          sessionLocalId: const Value(sessionLocalId),
          total: const Value(42),
        ),
      );

  Future<void> seedSyncedPayment({
    required String localId,
    required int serverId,
    String? session = sessionLocalId,
  }) =>
      db.into(db.paymentsTable).insert(
            PaymentsTableCompanion.insert(
              localId: localId,
              documentId: docLocalId,
              paymentTypeId: 1,
              amount: 42,
              userId: 9,
              date: now,
              companyId: const Value(25),
              serverId: Value(serverId),
              sessionLocalId: Value(session),
              syncStatus: const Value('synced'),
            ),
            mode: InsertMode.insertOrReplace,
          );

  /// The shape `refreshDocumentPaymentsFromServer` builds: a server snapshot,
  /// keyed `srvpay_<id>`, with no session of its own.
  PaymentsTableCompanion serverRow(int serverId) => PaymentsTableCompanion(
        localId: Value('srvpay_$serverId'),
        serverId: Value(serverId),
        documentId: const Value(docLocalId),
        paymentTypeId: const Value(1),
        amount: const Value(42),
        userId: const Value(9),
        date: Value(now),
        companyId: const Value(25),
        dateCreated: Value(now),
        syncStatus: const Value('synced'),
      );

  Future<List<PaymentsTableData>> paymentsOfSession(String session) =>
      (db.select(db.paymentsTable)
            ..where((t) => t.sessionLocalId.equals(session)))
          .get();

  group('reconcileServerPayments', () {
    test('keeps the payment on its session after a server refresh', () async {
      await seedDocument();
      await seedSyncedPayment(localId: 'pay-1', serverId: 900);

      await db.reconcileServerPayments(docLocalId, [serverRow(900)]);

      final rows = await paymentsOfSession(sessionLocalId);
      expect(rows, hasLength(1),
          reason: 'the session must still see the payment it took');
      expect(rows.single.amount, 42);
    });

    test('the session total survives it', () async {
      await seedDocument();
      await seedSyncedPayment(localId: 'pay-1', serverId: 900);

      await db.reconcileServerPayments(docLocalId, [serverRow(900)]);

      final total = (await paymentsOfSession(sessionLocalId))
          .fold<double>(0, (sum, r) => sum + r.amount);
      expect(total, 42,
          reason: 'expected cash is built from exactly these rows');
    });

    test('a payment with no session stays without one', () async {
      await seedDocument();
      await seedSyncedPayment(localId: 'pay-1', serverId: 900, session: null);

      await db.reconcileServerPayments(docLocalId, [serverRow(900)]);

      final row = await (db.select(db.paymentsTable)
            ..where((t) => t.serverId.equals(900)))
          .getSingle();
      expect(row.sessionLocalId, isNull,
          reason: 'nothing may be invented for a pre-session payment');
    });

    test('a server payment this device never saw arrives unlinked', () async {
      await seedDocument();

      await db.reconcileServerPayments(docLocalId, [serverRow(901)]);

      final row = await (db.select(db.paymentsTable)
            ..where((t) => t.serverId.equals(901)))
          .getSingle();
      expect(row.sessionLocalId, isNull,
          reason: 'another register took it; this device cannot know which '
              'session, and guessing would bank it in the wrong drawer');
    });

    test('a payment the server no longer has is dropped, not resurrected',
        () async {
      await seedDocument();
      await seedSyncedPayment(localId: 'pay-1', serverId: 900);

      await db.reconcileServerPayments(docLocalId, const []);

      expect(await paymentsOfSession(sessionLocalId), isEmpty);
    });

    test('an unsynced local payment is left alone entirely', () async {
      await seedDocument();
      await db.into(db.paymentsTable).insert(
            PaymentsTableCompanion.insert(
              localId: 'pay-local',
              documentId: docLocalId,
              paymentTypeId: 1,
              amount: 10,
              userId: 9,
              date: now,
              companyId: const Value(25),
              sessionLocalId: const Value(sessionLocalId),
              syncStatus: const Value('pending_create'),
            ),
          );

      await db.reconcileServerPayments(docLocalId, [serverRow(900)]);

      final rows = await paymentsOfSession(sessionLocalId);
      expect(rows.map((r) => r.localId), contains('pay-local'));
    });
  });
}
