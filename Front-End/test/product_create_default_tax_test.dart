// Regression for the second half of backlog item 5: a product created with the
// default tax pre-filled kept no tax at all.
//
// Phase 1 of the product editor writes the product to Drift under a NEGATIVE
// temp id and pops; only Phase 2 / Edit ever wrote a `product_taxes` row. So
// the pre-filled default was dropped on the floor, and reopening the product
// showed "No Tax". The fix writes the assignment in Phase 1 against the temp
// id — which is only safe because of the two invariants pinned below.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const companyId = 25;
  const tvaId = 4;
  const ecoId = 7;

  /// Mirrors what Phase 1 of `_ProductEditorDialog._submit` writes.
  Future<int> createProductOffline({int? withTaxId}) async {
    final tempId = -DateTime.now().microsecondsSinceEpoch;
    await db
        .into(db.productsTable)
        .insert(
          ProductsTableCompanion.insert(
            id: Value(tempId),
            companyId: companyId,
            name: 'Shwarma',
            syncStatus: const Value('pending_create'),
            lastModified: DateTime.now().toUtc(),
          ),
        );
    if (withTaxId != null) {
      await db.setProductTaxLocal(
        companyId: companyId,
        productId: tempId,
        oldTaxId: null,
        newTaxId: withTaxId,
      );
    }
    return tempId;
  }

  test('a product created offline keeps its default tax', () async {
    final tempId = await createProductOffline(withTaxId: tvaId);

    // What the editor re-reads when the product is reopened. Before the fix
    // this came back empty and the Taxes tab rendered "No Tax".
    final assigned = await db.getProductTaxes(tempId);
    expect(assigned.map((t) => t.taxId), [tvaId]);
    expect(assigned.single.syncStatus, 'pending_create');
  });

  test('the assignment survives the temp → real id remap', () async {
    // The invariant that makes writing against a negative id safe at all:
    // when the product push gets a server id, remapProductId repoints the
    // product_taxes row, so /ProductTaxes/Add never sends an unknown id.
    final tempId = await createProductOffline(withTaxId: tvaId);
    const realId = 9001;

    await db.remapProductId(tempId, realId);

    expect(await db.getProductTaxes(tempId), isEmpty);
    final moved = await db.getProductTaxes(realId);
    expect(moved.map((t) => t.taxId), [tvaId]);
    // Still unsynced — the push happens after the remap, not before.
    expect(moved.single.syncStatus, 'pending_create');
  });

  test(
    'changing the tax in Phase 2 replaces it instead of stacking a second one',
    () async {
      // Needs `_originalTaxId` to have been read back. When the editor skipped
      // that lookup for negative ids, this wrote the new tax while leaving the
      // old one in place and the product carried BOTH.
      final tempId = await createProductOffline(withTaxId: tvaId);

      final original = (await db.getProductTaxes(tempId)).single.taxId;
      await db.setProductTaxLocal(
        companyId: companyId,
        productId: tempId,
        oldTaxId: original,
        newTaxId: ecoId,
      );

      expect(await db.getProductTaxes(tempId), hasLength(1));
      expect((await db.getProductTaxes(tempId)).single.taxId, ecoId);
    },
  );

  test('creating with no default configured assigns no tax', () async {
    final tempId = await createProductOffline();
    expect(await db.getProductTaxes(tempId), isEmpty);
  });
}
