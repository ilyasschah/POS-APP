// Pins the local "is this tax still in use?" check the Tax Rates screen runs
// before deleting. It mirrors the server's three foreign keys on Tax, so a tax
// a product or a sale still uses is refused on the spot — offline included —
// instead of vanishing and quietly coming back after the server said no.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> assign(int productId, int taxId, {String status = 'synced'}) =>
      db.into(db.productTaxesTable).insert(ProductTaxesTableCompanion.insert(
            productId: productId,
            taxId: taxId,
            companyId: 1,
            syncStatus: Value(status),
          ));

  test('an unused tax is free to delete', () async {
    final usage = await db.taxUsageLocal(7);
    expect(usage.products, 0);
    expect(usage.inDocuments, isFalse);
  });

  test('counts the products assigned the tax, and only that tax', () async {
    await assign(1, 7);
    await assign(2, 7);
    await assign(3, 8);

    expect((await db.taxUsageLocal(7)).products, 2);
    expect((await db.taxUsageLocal(8)).products, 1);
  });

  test('a product link already queued for removal no longer counts', () async {
    await assign(1, 7, status: 'pending_delete');

    expect((await db.taxUsageLocal(7)).products, 0);
  });

  test('a document line carrying the tax blocks it', () async {
    await db.into(db.documentItemTaxesTable).insert(
          DocumentItemTaxesTableCompanion.insert(
            documentItemId: 1,
            taxId: 7,
            amount: 2.0,
            companyId: 1,
          ),
        );

    expect((await db.taxUsageLocal(7)).inDocuments, isTrue);
    expect((await db.taxUsageLocal(8)).inDocuments, isFalse);
  });
}
