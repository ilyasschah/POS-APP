// Pins what a kitchen ticket says about the ORDER (as opposed to its items).
//
// Both lookups were inline expressions in the menu button and both were wrong in
// ways nothing in the repo could catch — no compile error, no lint, no failing
// test. They are only visible on paper, in a kitchen, mid-service:
//
//   • the service type was a hardcoded English switch
//     (0→"Dine In", 1→"Takeaway", _→"Order") that ignored the venue's
//     `Pos.CustomServiceTypes` entirely. It did not even match the shipped
//     defaults ("Dine-In", with a hyphen), and Delivery — plus every type an
//     operator adds — printed as the meaningless word "Order".
//   • the table reached the kitchen ONLY by accident, embedded in the order
//     number ("ORD- Table 1"). Any change to order naming would have silently
//     stopped telling the kitchen where the food goes.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/service_type_model.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/printer/kitchen_ticket_data.dart';

/// The shipped defaults from `kSettingDefaults[customServiceTypes]`.
const _defaults = [
  CustomServiceType(id: 0, name: 'Dine-In', prefix: 'ORDER'),
  CustomServiceType(id: 1, name: 'Takeaway', prefix: 'TAKEAWAY'),
  CustomServiceType(id: 2, name: 'Delivery', prefix: 'DELIVERY'),
];

FloorPlanTable _table(int id, String name) => FloorPlanTable(
      id: id,
      name: name,
      floorPlanId: 1,
      positionX: 0,
      positionY: 0,
      width: 80,
      height: 80,
      isRound: false,
    );

void main() {
  group('serviceLabel', () {
    test('uses the venue\'s own wording, not a hardcoded English one', () {
      // The old switch printed "Dine In"; the configured name is "Dine-In".
      expect(
        KitchenTicketData.serviceLabel(_defaults, 0, fallback: 'Order'),
        'Dine-In',
      );
    });

    test('a type past the first two is no longer flattened to "Order"', () {
      // This is the real damage: Delivery — and every operator-added type —
      // reached the kitchen indistinguishable from a plain order.
      expect(
        KitchenTicketData.serviceLabel(_defaults, 2, fallback: 'Order'),
        'Delivery',
      );
    });

    test('a fully custom set is honoured', () {
      const custom = [
        CustomServiceType(id: 0, name: 'Sur place', prefix: 'SP'),
        CustomServiceType(id: 7, name: 'Drive', prefix: 'DR'),
      ];
      expect(KitchenTicketData.serviceLabel(custom, 7, fallback: 'Order'),
          'Drive');
    });

    test('an unknown id falls back instead of printing nothing', () {
      // A stale order whose service type was later deleted.
      expect(
        KitchenTicketData.serviceLabel(_defaults, 99, fallback: 'Order'),
        'Order',
      );
      expect(
        KitchenTicketData.serviceLabel(const [], 0, fallback: 'Order'),
        'Order',
      );
    });

    test('a blank configured name falls back rather than printing empty', () {
      const blank = [CustomServiceType(id: 0, name: '   ', prefix: 'X')];
      expect(KitchenTicketData.serviceLabel(blank, 0, fallback: 'Order'),
          'Order');
    });
  });

  group('tableName', () {
    final tables = [_table(6, 'Table 1'), _table(28, 'A3'), _table(30, 'A5')];

    test('resolves the table to its display name', () {
      expect(KitchenTicketData.tableName(tables, 28), 'A3');
    });

    test('no table → null, so the line is omitted entirely', () {
      // Takeaway/delivery. Null rather than '' or a placeholder, so the ticket
      // never prints a bare "Table" label with nothing after it.
      expect(KitchenTicketData.tableName(tables, null), isNull);
    });

    test('a deleted table → null, not a half-printed line', () {
      expect(KitchenTicketData.tableName(tables, 999), isNull);
      expect(KitchenTicketData.tableName(const [], 6), isNull);
    });

    test('a blank table name → null', () {
      expect(KitchenTicketData.tableName([_table(1, '  ')], 1), isNull);
    });

    test('surrounding whitespace is trimmed off the printed name', () {
      expect(KitchenTicketData.tableName([_table(1, '  Terrace 2 ')], 1),
          'Terrace 2');
    });
  });
}
