import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_display/kds_models.dart';

/// Replaces the generated `widget_test.dart`, which pumped `KitchenDisplayApp`
/// and asserted a counter incremented — the Flutter scaffold's own test, left
/// untouched. There is no counter in a kitchen display, so it could never have
/// passed; it only went unnoticed because no workflow ran it.
///
/// Pumping the real app is not the replacement: `RootScreen.initState` boots the
/// LAN server and touches storage, so a widget test would bind a socket on the
/// runner. The parsing in `kds_models.dart` is where the actual risk lives — it
/// is the wire contract between a POS and a display that may be on different
/// versions — and it is pure, so it tests cleanly.
void main() {
  group('KitchenItem.fromJson', () {
    test('reads productName, and falls back to name for an older POS', () {
      expect(
        KitchenItem.fromJson({'id': 1, 'productName': 'Steak'}).name,
        'Steak',
      );
      expect(KitchenItem.fromJson({'id': 1, 'name': 'Steak'}).name, 'Steak');
    });

    test('names an item rather than rendering a blank line', () {
      expect(KitchenItem.fromJson({'id': 1}).name, 'Unknown Item');
    });

    test('defaults quantity to 1 and widens an int to double', () {
      expect(KitchenItem.fromJson({'id': 1}).quantity, 1.0);
      expect(KitchenItem.fromJson({'id': 1, 'quantity': 3}).quantity, 3.0);
      expect(KitchenItem.fromJson({'id': 1, 'quantity': 1.5}).quantity, 1.5);
    });

    test('keeps modifier names, trimmed', () {
      final item = KitchenItem.fromJson({
        'id': 1,
        'modifiers': ['  Extra Cheese  ', 'No Sugar'],
      });
      expect(item.modifiers, ['Extra Cheese', 'No Sugar']);
    });

    test('drops blank and non-string modifiers instead of showing junk', () {
      final item = KitchenItem.fromJson({
        'id': 1,
        'modifiers': ['Extra Cheese', '', '   ', 42, null],
      });
      expect(item.modifiers, ['Extra Cheese']);
    });

    test('a POS predating modifiers yields an empty list, not a crash', () {
      expect(KitchenItem.fromJson({'id': 1}).modifiers, isEmpty);
    });
  });

  group('KitchenOrder.fromJson', () {
    test('prefers orderRef but accepts a legacy id as the echo key', () {
      expect(
        KitchenOrder.fromJson({'orderRef': 'abc', 'id': 9}).orderRef,
        'abc',
      );
      expect(KitchenOrder.fromJson({'id': 9}).orderRef, '9');
      expect(KitchenOrder.fromJson({}).orderRef, '');
    });

    test('accepts serviceType in either casing', () {
      expect(KitchenOrder.fromJson({'serviceType': 2}).serviceType, 2);
      expect(KitchenOrder.fromJson({'ServiceType': 3}).serviceType, 3);
      expect(KitchenOrder.fromJson({}).serviceType, 1);
    });

    test('parses nested items', () {
      final order = KitchenOrder.fromJson({
        'orderRef': 'o1',
        'items': [
          {'id': 1, 'productName': 'Fries', 'quantity': 2},
          {'id': 2, 'productName': 'Coke'},
        ],
      });
      expect(order.items, hasLength(2));
      expect(order.items.first.name, 'Fries');
      expect(order.items.first.quantity, 2.0);
    });

    test('an order with no items parses to an empty ticket', () {
      expect(KitchenOrder.fromJson({'orderRef': 'o1'}).items, isEmpty);
    });

    test('an unparseable date leaves dateCreated null rather than throwing', () {
      expect(
        KitchenOrder.fromJson({'orderRef': 'o1', 'dateCreated': 'not-a-date'})
            .dateCreated,
        isNull,
      );
    });
  });

  group('KitchenOrder.typeString', () {
    test('maps the known service types', () {
      String typeFor(int t) =>
          KitchenOrder.fromJson({'serviceType': t}).typeString;

      expect(typeFor(1), 'Dine in');
      expect(typeFor(2), 'Takeaway');
      expect(typeFor(3), 'Delivery');
    });

    test('falls back for an unknown type', () {
      expect(KitchenOrder.fromJson({'serviceType': 99}).typeString, 'Order');
    });
  });

  group('KitchenOrder.headerColor', () {
    KitchenOrder agedMinutes(int minutes) => KitchenOrder.fromJson({
          'orderRef': 'o1',
          'dateCreated': DateTime.now()
              .subtract(Duration(minutes: minutes))
              .toIso8601String(),
        });

    const fresh = 0xFFAED581;
    const warning = 0xFFFFF176;
    const overdue = 0xFFFF8A65;

    test('a fresh ticket is green', () {
      expect(agedMinutes(1).headerColor.toARGB32(), fresh);
    });

    test('past five minutes it turns yellow', () {
      expect(agedMinutes(6).headerColor.toARGB32(), warning);
    });

    test('past fifteen minutes it turns orange', () {
      expect(agedMinutes(16).headerColor.toARGB32(), overdue);
    });

    test('an undated ticket is treated as fresh, not as overdue', () {
      expect(
        KitchenOrder.fromJson({'orderRef': 'o1'}).headerColor.toARGB32(),
        fresh,
      );
    });
  });

  group('round trip', () {
    test('toJson output parses back to the same ticket', () {
      final original = KitchenOrder.fromJson({
        'orderRef': 'o-42',
        'number': 'A17',
        'tableName': 'T3',
        'serviceType': 2,
        'serviceStatus': 2,
        'items': [
          {
            'id': 1,
            'productName': 'Burger',
            'quantity': 2,
            'comment': 'well done',
            'modifiers': ['No Onion'],
          },
        ],
      });

      final restored = KitchenOrder.fromJson(original.toJson());

      expect(restored.orderRef, original.orderRef);
      expect(restored.number, original.number);
      expect(restored.tableName, original.tableName);
      expect(restored.serviceType, original.serviceType);
      expect(restored.items.single.name, 'Burger');
      expect(restored.items.single.quantity, 2.0);
      expect(restored.items.single.comment, 'well done');
      expect(restored.items.single.modifiers, ['No Onion']);
    });
  });
}
