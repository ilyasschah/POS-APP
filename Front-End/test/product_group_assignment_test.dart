// End-to-end regression for item 16 — "changing a product's group from the
// Product Groups screen doesn't take effect".
//
// The bug: the editor's Products-tab save only POSTed /ProductGroups/AssignProducts
// and never wrote Drift, yet every screen streams products FROM Drift, so nothing
// updated until a full product pull. The fix (applyGroupMembershipLocally) writes
// the new group locally and marks the rows pending_update so the sync pushes them.
//
// These drive the extracted function against a real (in-memory) Drift DB and
// assert the actual rows — move in, unassign out, mixed, "only changed touched",
// and company isolation.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/product/product_group_assignment.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const companyId = 25;

  Future<void> addProduct(
    int id, {
    int? groupId,
    String status = 'synced',
    int company = companyId,
  }) async {
    await db.into(db.productsTable).insert(
          ProductsTableCompanion.insert(
            id: Value(id),
            companyId: company,
            name: 'P$id',
            productGroupId: Value(groupId),
            syncStatus: Value(status),
            lastModified: DateTime.now().toUtc(),
          ),
        );
  }

  Future<({int? group, String status})> row(int id) async {
    final p = await (db.select(db.productsTable)..where((t) => t.id.equals(id)))
        .getSingle();
    return (group: p.productGroupId, status: p.syncStatus);
  }

  test('moving a product A→B lands in Drift + marks it pending_update', () async {
    await addProduct(1, groupId: 10); // in group A
    await addProduct(2, groupId: 20); // already in group B

    // Editing group B; both boxes ticked (2 was already in B, 1 is moving in).
    final r = await applyGroupMembershipLocally(
      db,
      companyId: companyId,
      groupId: 20,
      checkedIds: [1, 2],
    );

    expect(r.moved, 1, reason: 'only product 1 actually changed group');
    expect((await row(1)).group, 20);
    expect((await row(1)).status, 'pending_update');

    // Product 2 was already in B → left untouched, NOT needlessly re-pushed.
    expect((await row(2)).group, 20);
    expect((await row(2)).status, 'synced');
  });

  test('un-checking a product unassigns it (null + pending_update)', () async {
    await addProduct(1, groupId: 20);
    await addProduct(2, groupId: 20);

    // Editing group B; only product 1 stays ticked → product 2 removed.
    final r = await applyGroupMembershipLocally(
      db,
      companyId: companyId,
      groupId: 20,
      checkedIds: [1],
    );

    expect(r.removed, 1);
    expect((await row(2)).group, isNull, reason: 'unassigned');
    expect((await row(2)).status, 'pending_update');

    // The still-ticked one is unchanged.
    expect((await row(1)).group, 20);
    expect((await row(1)).status, 'synced');
  });

  test('un-checking everything empties the group', () async {
    await addProduct(1, groupId: 20);
    await addProduct(2, groupId: 20);

    final r = await applyGroupMembershipLocally(
      db,
      companyId: companyId,
      groupId: 20,
      checkedIds: const [],
    );

    expect(r.removed, 2);
    expect((await row(1)).group, isNull);
    expect((await row(2)).group, isNull);
  });

  test('a move-in and a remove-out in one save', () async {
    await addProduct(1, groupId: 10); // in A
    await addProduct(2, groupId: 20); // in B

    // Editing B: tick 1 (move in), untick 2 (remove out).
    final r = await applyGroupMembershipLocally(
      db,
      companyId: companyId,
      groupId: 20,
      checkedIds: [1],
    );

    expect(r.moved, 1);
    expect(r.removed, 1);
    expect((await row(1)).group, 20);
    expect((await row(1)).status, 'pending_update');
    expect((await row(2)).group, isNull);
    expect((await row(2)).status, 'pending_update');
  });

  test('a product with no group can be assigned', () async {
    await addProduct(1); // productGroupId == null

    final r = await applyGroupMembershipLocally(
      db,
      companyId: companyId,
      groupId: 20,
      checkedIds: [1],
    );

    expect(r.moved, 1);
    expect((await row(1)).group, 20);
    expect((await row(1)).status, 'pending_update');
  });

  test('another company is never touched', () async {
    await addProduct(1, groupId: 20); // company 25
    await addProduct(99, groupId: 20, company: 999); // different company, same group id

    // Empty the group for company 25 — must not reach company 999's row.
    await applyGroupMembershipLocally(
      db,
      companyId: companyId,
      groupId: 20,
      checkedIds: const [],
    );

    expect((await row(1)).group, isNull); // ours cleared
    expect((await row(99)).group, 20); // theirs untouched
    expect((await row(99)).status, 'synced');
  });
}
