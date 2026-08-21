// Regression for the item-16 follow-up: a product group DELETED on device A must
// disappear on device B after a (manual) sync.
//
// A delta pull is blind to deletions — the deleted row is simply absent from a
// "changed since" response — so the fix reconciles on the full pass: any locally
// `synced` group the server no longer returns is retired. These drive that
// reconcile against a real in-memory Drift DB and pin the load-bearing guard:
// pending local ops (create/update/delete not yet pushed) are NEVER wiped.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/product/product_group_reconcile.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  const companyId = 25;

  Future<void> addGroup(
    int id, {
    String status = 'synced',
    String? icon,
    int company = companyId,
  }) async {
    await db.into(db.productGroupsTable).insert(
          ProductGroupsTableCompanion.insert(
            id: Value(id),
            companyId: company,
            name: 'G$id',
            syncStatus: Value(status),
            localImagePath: Value(icon),
            lastModified: DateTime.now().toUtc(),
          ),
        );
  }

  Future<Set<int>> localGroupIds() async {
    final rows = await db.select(db.productGroupsTable).get();
    return rows.map((g) => g.id).toSet();
  }

  test('a synced group the server no longer returns is retired', () async {
    await addGroup(1); // still on server
    await addGroup(2); // deleted on the other device

    final r = await retireDeletedProductGroups(
      db,
      companyId: companyId,
      serverIds: {1}, // server returned only group 1
    );

    expect(r.removed, 1);
    expect(await localGroupIds(), {1});
  });

  test('returns the icon path of a retired group so the file can be cleaned',
      () async {
    await addGroup(2, icon: '/data/group_images/2_image.png');

    final r = await retireDeletedProductGroups(
      db,
      companyId: companyId,
      serverIds: const {},
    );

    expect(r.removed, 1);
    expect(r.iconPaths, ['/data/group_images/2_image.png']);
  });

  test('pending local groups are NEVER wiped (only synced rows)', () async {
    await addGroup(1, status: 'pending_create'); // created offline, not pushed
    await addGroup(2, status: 'pending_update'); // edited offline
    await addGroup(3, status: 'pending_delete'); // deleted offline, pusher owns it
    await addGroup(4); // synced, and gone from server → the only one to retire

    final r = await retireDeletedProductGroups(
      db,
      companyId: companyId,
      serverIds: const {}, // server returned nothing
    );

    expect(r.removed, 1, reason: 'only the synced row 4');
    expect(await localGroupIds(), {1, 2, 3},
        reason: 'the three pending rows survive');
  });

  test('another company is never touched', () async {
    await addGroup(1); // company 25, gone from server
    await addGroup(99, company: 999); // different company

    await retireDeletedProductGroups(
      db,
      companyId: companyId,
      serverIds: const {},
    );

    expect(await localGroupIds(), {99}, reason: 'only company 25 reconciled');
  });

  test('nothing is removed when the server still has every local group',
      () async {
    await addGroup(1);
    await addGroup(2);

    final r = await retireDeletedProductGroups(
      db,
      companyId: companyId,
      serverIds: {1, 2},
    );

    expect(r.removed, 0);
    expect(await localGroupIds(), {1, 2});
  });
}
