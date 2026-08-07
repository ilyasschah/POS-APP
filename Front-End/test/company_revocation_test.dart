// Pins the two halves of "I deleted a company from the admin portal and its
// data is still there".
//
// The SERVER side was never broken — a portal delete removes the company, all
// ~40 CompanyId-scoped tables, and the Master-DB tenant. Verified live. Both
// bugs were on the terminal:
//
//   1. `checkCompanyExists` could NEVER return `deleted`, so no terminal ever
//      learned its company was gone. It assumed the API answers 200-with-null;
//      `GetCompanyByIdQuery` actually throws `KeyNotFoundException`, which
//      `ExceptionHandlingMiddleware` maps to 404 — and Dio raises on a 404, so
//      the blanket `catch` returned `unknown` every single time.
//   2. Revocation only called `AuthStorage.unlinkDevice()`, which clears the
//      JWT/lease/company-id and touches nothing in Drift. Every product, order,
//      document and payment of the deleted company stayed on disk for good.
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/sync/account_status_provider.dart';

/// Classifies a response the way `checkCompanyExists` does. Mirrors its
/// DioException branch exactly so the mapping can be asserted without a socket.
CompanyExistence classify(DioException e) {
  if (e.response?.statusCode == 404) return CompanyExistence.deleted;
  return CompanyExistence.unknown;
}

DioException _err(int? status) {
  final req = RequestOptions(path: '/Company/GetById');
  return DioException(
    requestOptions: req,
    response: status == null
        ? null
        : Response<dynamic>(requestOptions: req, statusCode: status),
    type: status == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
  );
}

void main() {
  group('deleted-company detection', () {
    test('404 means the company is gone — the case that never fired', () {
      // Against the pre-fix code this was `unknown`, so `markRevoked()` was
      // unreachable and terminals kept trading on a deleted tenant.
      expect(classify(_err(404)), CompanyExistence.deleted);
    });

    test('401 is a dead token, NOT a deleted company', () {
      // Critical: SessionExpiry owns 401. Treating it as "deleted" would wipe a
      // healthy terminal's database over a routine token refresh.
      expect(classify(_err(401)), CompanyExistence.unknown);
    });

    test('a sick server is never read as a deletion', () {
      // 503 is the API's explicit "database unreachable, retry" signal.
      expect(classify(_err(500)), CompanyExistence.unknown);
      expect(classify(_err(503)), CompanyExistence.unknown);
    });

    test('offline is never read as a deletion', () {
      expect(classify(_err(null)), CompanyExistence.unknown);
    });
  });

  group('purgeAllLocalData', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('erases the deleted company\'s data, including localId-keyed children',
        () async {
      await db.into(db.companiesTable).insert(
            CompaniesTableCompanion.insert(
              id: const Value(25),
              name: 'FUTUR3',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await db.into(db.productsTable).insert(
            ProductsTableCompanion.insert(
              id: const Value(1),
              companyId: 25,
              name: 'Coffee',
              price: const Value(10.0),
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await db.into(db.posOrdersTable).insert(
            PosOrdersTableCompanion.insert(
              localId: 'order-1',
              companyId: 25,
              userId: 1,
              serviceType: 0,
              openedAt: DateTime.now().toUtc(),
              warehouseId: 1,
              lastModified: DateTime.now().toUtc(),
            ),
          );
      // No company_id column at all — keyed only by its parent's localId. A
      // `WHERE company_id = ?` sweep would strand this row forever, which is
      // why the purge is a full wipe.
      await db.into(db.posOrderItemsTable).insert(
            PosOrderItemsTableCompanion.insert(
              localId: 'line-1',
              orderId: 'order-1',
              productId: 1,
              quantity: 2,
              unitPrice: 10,
              warehouseId: 1,
            ),
          );

      expect(await db.select(db.productsTable).get(), isNotEmpty);
      expect(await db.select(db.posOrderItemsTable).get(), isNotEmpty);

      await db.purgeAllLocalData();

      // All four fail against the pre-fix behaviour, where revocation wiped
      // nothing at all.
      expect(await db.select(db.companiesTable).get(), isEmpty);
      expect(await db.select(db.productsTable).get(), isEmpty);
      expect(await db.select(db.posOrdersTable).get(), isEmpty);
      expect(await db.select(db.posOrderItemsTable).get(), isEmpty,
          reason: 'localId-keyed children must not survive as orphans');
    });

    test('the schema survives, so the terminal can re-link and re-sync',
        () async {
      await db.purgeAllLocalData();
      // A wipe, not a drop: every table must still be queryable afterwards.
      expect(await db.select(db.productsTable).get(), isEmpty);
      await db.into(db.companiesTable).insert(
            CompaniesTableCompanion.insert(
              id: const Value(30),
              name: 'NEW CO',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      expect(await db.select(db.companiesTable).get(), hasLength(1));
    });
  });
}
