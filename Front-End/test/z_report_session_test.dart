// Pins the Z-report that closing a POS session now generates.
//
// Before this, `closeSession` marked the shift row closed and left the report
// to the server's `GenerateForSessionAsync` — so an offline till shut its
// drawer with no slip to print and nothing on screen. The report is now built
// locally, scoped to the session, by the SAME service End of Day uses.
//
// The expensive failure this guards is DOUBLE COUNTING: a session close that
// did not stamp what it reported would leave its sales in the company-wide
// unreported set, and the next End of Day would bank the same money twice.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:pos_app/reports/z_report_service.dart';

void main() {
  late AppDatabase db;

  const companyId = 25;
  const userId = 9;
  const sessionA = 'session-a';
  const sessionB = 'session-b';

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A settled sale: document + one line + the payment that closed it.
  Future<void> sale({
    required String id,
    required String sessionLocalId,
    required double total,
    required double tax,
    required int paymentTypeId,
    String? number,
    int documentTypeId = DocumentTypes.sales,
    double? paid,
  }) async {
    await db.into(db.documentsTable).insert(DocumentsTableCompanion.insert(
          localId: id,
          companyId: companyId,
          userId: userId,
          warehouseId: 17,
          date: DateTime.utc(2026, 8, 24, 10),
          total: Value(total),
          number: Value(number),
          documentTypeId: Value(documentTypeId),
          sessionLocalId: Value(sessionLocalId),
          lastModified: DateTime.utc(2026, 8, 24, 10),
        ));
    await db.into(db.documentItemsTable).insert(
          DocumentItemsTableCompanion.insert(
            localId: '$id-item',
            documentId: id,
            productId: 1,
            quantity: 1,
            unitPrice: total,
            total: total,
            taxAmount: Value(tax),
          ),
        );
    await db.into(db.paymentsTable).insert(PaymentsTableCompanion.insert(
          localId: '$id-pay',
          documentId: id,
          paymentTypeId: paymentTypeId,
          amount: paid ?? total,
          userId: userId,
          date: DateTime.utc(2026, 8, 24, 10),
          companyId: const Value(companyId),
          sessionLocalId: Value(sessionLocalId),
        ));
  }

  Future<void> cashMovement(String id, String sessionLocalId, String type,
      double amount) async {
    await db.into(db.startingCashTable).insert(
          StartingCashTableCompanion.insert(
            localId: id,
            companyId: companyId,
            userId: userId,
            amount: amount,
            type: type,
            createdAt: DateTime.utc(2026, 8, 24, 12),
            sessionLocalId: Value(sessionLocalId),
          ),
        );
  }

  Future<void> paymentType(int id, String name) async {
    await db.into(db.paymentTypesTable).insert(
          PaymentTypesTableCompanion.insert(
            id: Value(id),
            companyId: companyId,
            name: name,
            lastModified: DateTime.utc(2026, 8, 24),
          ),
        );
  }

  Future<ZReportModel?> closeSessionA() => ZReportService.generate(
        db: db,
        companyId: companyId,
        userId: userId,
        scope: ZReportScope.session,
        sessionLocalId: sessionA,
      );

  /// Asserts a report came back and hands it over, so each test reads as the
  /// arithmetic it is checking rather than as a null dance.
  ZReportModel require(ZReportModel? report) {
    expect(report, isNotNull, reason: 'expected a Z-report to be generated');
    return report!;
  }

  group('a session close reports on its own sales only', () {
    setUp(() async {
      await paymentType(1, 'Cash');
      await paymentType(2, 'Card');
      await sale(
          id: 'a1',
          sessionLocalId: sessionA,
          total: 120,
          tax: 20,
          paymentTypeId: 1,
          number: '26-025-000001');
      await sale(
          id: 'a2',
          sessionLocalId: sessionA,
          total: 60,
          tax: 10,
          paymentTypeId: 2,
          number: '26-025-000002');
      // Another register, trading at the same time. Must not appear.
      await sale(
          id: 'b1',
          sessionLocalId: sessionB,
          total: 500,
          tax: 80,
          paymentTypeId: 1,
          number: '26-025-000003');
    });

    test('totals cover this session and nothing else', () async {
      final report = require(await closeSessionA());
      expect(report.totalSales, 180);
      expect(report.totalTax, 30);
      expect(report.taxableTotal, 150);
      expect(report.grandTotal, 180);
      expect(report.documentCount, 2);
    });

    test('the document range is this session\'s first and last', () async {
      final report = require(await closeSessionA());
      expect(report.fromDocumentNumber, '26-025-000001');
      expect(report.toDocumentNumber, '26-025-000002');
    });

    test('the tender breakdown splits by method', () async {
      final report = require(await closeSessionA());
      final byName = {
        for (final s in report.paymentSummaries) s.paymentTypeName: s.totalAmount
      };
      expect(byName, {'Cash': 120.0, 'Card': 60.0});
    });

    test('cash in/out is the session\'s own drawer movement', () async {
      await cashMovement('m1', sessionA, 'in', 200);
      await cashMovement('m2', sessionA, 'out', 50);
      await cashMovement('m3', sessionB, 'in', 999); // another register
      final report = require(await closeSessionA());
      expect(report.totalCashIn, 200);
      expect(report.totalCashOut, 50);
    });

    test('a refund reduces the take without being counted as a sale', () async {
      await sale(
        id: 'a3',
        sessionLocalId: sessionA,
        total: -40,
        tax: 0,
        paymentTypeId: 1,
        documentTypeId: DocumentTypes.refund,
        paid: -40,
      );
      final report = require(await closeSessionA());
      // Classified by type, never by the stored sign.
      expect(report.totalReturns, 40);
      expect(report.totalSales, 180);
      // What actually hit the drawer.
      expect(report.grandTotal, 140);
    });
  });

  group('the same money is never reported twice', () {
    setUp(() async {
      await paymentType(1, 'Cash');
      await sale(
          id: 'a1', sessionLocalId: sessionA, total: 100, tax: 0,
          paymentTypeId: 1);
      await sale(
          id: 'b1', sessionLocalId: sessionB, total: 250, tax: 0,
          paymentTypeId: 1);
      await cashMovement('m1', sessionA, 'in', 30);
    });

    test('closing a session stamps its payments out of the unreported set',
        () async {
      expect(await db.getUnreportedPayments(companyId), hasLength(2));
      await closeSessionA();
      final left = await db.getUnreportedPayments(companyId);
      expect(left, hasLength(1));
      expect(left.single.documentId, 'b1');
    });

    test('a later End of Day banks only what is left — not the session again',
        () async {
      await closeSessionA();
      final day = await ZReportService.generate(
        db: db,
        companyId: companyId,
        userId: userId,
        scope: ZReportScope.company,
      );
      expect(day, isNotNull);
      expect(day!.grandTotal, 250);
      expect(day.documentCount, 1);
    });

    test('closing the same session twice reports nothing the second time',
        () async {
      expect(await closeSessionA(), isNotNull);
      expect(await closeSessionA(), isNull);
    });

    test('the session\'s cash movements are finalised too', () async {
      await closeSessionA();
      expect(await db.getActiveSessionStartingCash(sessionA), isEmpty);
    });

    test('Z-report numbers keep advancing across both scopes', () async {
      final first = require(await closeSessionA());
      final second = await ZReportService.generate(
        db: db,
        companyId: companyId,
        userId: userId,
        scope: ZReportScope.company,
      );
      expect(first.number, 1);
      expect(second!.number, 2);
    });
  });

  group('empty scopes', () {
    test('a session that took no money produces no report', () async {
      final report = await ZReportService.generate(
        db: db,
        companyId: companyId,
        userId: userId,
        scope: ZReportScope.session,
        sessionLocalId: 'never-sold-anything',
      );
      // Writing an empty row would burn a number and make the sequence lie
      // about how many times the register was closed.
      expect(report, isNull);
      expect(await db.getZReportHistory(companyId), isEmpty);
    });
  });

  group('preview — the "Print Z Report" button', () {
    setUp(() async {
      await paymentType(1, 'Cash');
      await sale(
          id: 'a1', sessionLocalId: sessionA, total: 100, tax: 20,
          paymentTypeId: 1);
      await cashMovement('m1', sessionA, 'in', 40);
    });

    test('reports the same figures as the real close would', () async {
      final preview = await ZReportService.preview(
        db: db, companyId: companyId, sessionLocalId: sessionA);
      expect(preview, isNotNull);
      expect(preview!.totalSales, 100);
      expect(preview.totalTax, 20);
      expect(preview.grandTotal, 100);
      expect(preview.totalCashIn, 40);
      expect(preview.paymentSummaries.single.paymentTypeName, 'Cash');
    });

    test('writes NOTHING — reading the drawer must not close it', () async {
      await ZReportService.preview(
          db: db, companyId: companyId, sessionLocalId: sessionA);

      expect(await db.getZReportHistory(companyId), isEmpty);
      expect(await db.getUnreportedPayments(companyId), hasLength(1));
      expect(await db.getActiveSessionStartingCash(sessionA), hasLength(1));

      // …and the real close still reports the full session afterwards.
      final report = require(await closeSessionA());
      expect(report.grandTotal, 100);
    });

    test('carries no number, so the sequence is untouched', () async {
      final preview = await ZReportService.preview(
          db: db, companyId: companyId, sessionLocalId: sessionA);
      expect(preview!.number, 0);
      final real = require(await closeSessionA());
      expect(real.number, 1);
    });
  });
}
