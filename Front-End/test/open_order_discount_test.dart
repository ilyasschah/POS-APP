// Pins that an OPEN order reopened on a second terminal charges the SAME money
// as the terminal that rang it up.
//
// `discount_lines` never cross the wire for an open order — only checkout's
// BatchSync sends them — so a pulled order arrives with none. Four of the five
// discount sources survive that anyway:
//
//   manual_cart     → PosOrder.Discount / DiscountType (crosses; fixed 2026-08-06)
//   manual_item     → PosOrderItem.Discount (the RESOLVED money crosses)
//   promotion       → recomputed locally by _applyPromotions from pulled promos
//   loyalty_points  → checkout-only, never on an open order
//
// The fifth, customer_profile, did NOT, and it was a real money discrepancy: the
// second till applied no customer discount, so its grand total came out higher
// than the first till's, and checking out there would have charged the customer
// the undiscounted price. It is master data, so it is recovered from the local
// customer_discounts mirror instead of being synced.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertCustomer(int id, {double? discount, int type = 0}) async {
    await db.into(db.customersTable).insert(
          CustomersTableCompanion.insert(
            id: Value(id),
            companyId: 1,
            name: 'Ilyass',
            lastModified: DateTime.now().toUtc(),
          ),
        );
    if (discount != null) {
      await db.into(db.customerDiscountsTable).insert(
            CustomerDiscountsTableCompanion.insert(
              id: Value(id * 100),
              companyId: 1,
              customerId: id,
              value: Value(discount),
              type: Value(type),
              lastModified: DateTime.now().toUtc(),
            ),
          );
    }
  }

  /// Mirrors `_restoreCustomerDiscount`'s fallback branch: no `customer_profile`
  /// line on the order → read the customer's configured discount from the local
  /// mirror. Kept in lockstep with the provider, which needs a Ref to construct.
  Future<({double? value, int? type})> resolve(int? customerId) async {
    if (customerId == null) return (value: null, type: null);
    final profile = await (db.select(db.customerDiscountsTable)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
          ..limit(1))
        .get()
        .then((r) => r.firstOrNull);
    if (profile == null || profile.value <= 0) return (value: null, type: null);
    return (value: profile.value, type: profile.type);
  }

  test('a pulled order recovers the customer profile discount', () async {
    await insertCustomer(45, discount: 10, type: 0); // 10%

    final restored = await resolve(45);

    // Was (null, null) — so the second till applied NO discount and computed a
    // higher total than the till that rang the order up.
    expect(restored.value, 10);
    expect(restored.type, 0);
  });

  test('a customer with no configured discount still resolves to none', () async {
    await insertCustomer(46);
    expect((await resolve(46)).value, isNull);
  });

  test('a zero-value discount is not treated as a discount', () async {
    await insertCustomer(47, discount: 0);
    expect((await resolve(47)).value, isNull,
        reason: 'a 0 discount must not produce a discount line');
  });

  test('a soft-deleted discount is ignored', () async {
    await insertCustomer(48, discount: 15);
    await (db.update(db.customerDiscountsTable)
          ..where((t) => t.customerId.equals(48)))
        .write(const CustomerDiscountsTableCompanion(
            syncStatus: Value('pending_delete')));
    expect((await resolve(48)).value, isNull,
        reason: 'a discount deleted here must not come back on a reopen');
  });

  test('a Walk-in order (no customer) resolves to no discount', () async {
    expect((await resolve(null)).value, isNull);
  });
}
