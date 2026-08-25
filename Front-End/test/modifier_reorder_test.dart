// Dragging a product's modifier groups into the order the cashier is asked.
//
// The order is not cosmetic — it is the sequence of questions the customise
// sheet puts to the cashier mid-sale, so "Doneness" before "Sauce" on a steak
// is a real decision. It is also the classic off-by-one:
// ReorderableListView reports the destination as an index in the list BEFORE
// the dragged item is removed, so anything dragged DOWNWARD arrives one place
// too far. Dragging to the end is where it shows — the item lands
// second-from-last and nobody notices until a cashier complains.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/modifier/modifier_models.dart';

void main() {
  // Three groups, as they would come back from the link table.
  const abc = ['a', 'b', 'c'];

  group('dragging downward', () {
    test('first to last really is last', () {
      // The case the -1 correction exists for. Without it this returns
      // ['b', 'a', 'c'] — dropped one short of where the finger let go.
      expect(reorderedForDrag(abc, 0, 3), ['b', 'c', 'a']);
    });

    test('first to the middle', () {
      expect(reorderedForDrag(abc, 0, 2), ['b', 'a', 'c']);
    });

    test('middle to last', () {
      expect(reorderedForDrag(abc, 1, 3), ['a', 'c', 'b']);
    });
  });

  group('dragging upward', () {
    test('last to first', () {
      // Upward drags need NO correction — applying one anyway is the mirror
      // bug, and it is why the adjustment is conditional.
      expect(reorderedForDrag(abc, 2, 0), ['c', 'a', 'b']);
    });

    test('last to the middle', () {
      expect(reorderedForDrag(abc, 2, 1), ['a', 'c', 'b']);
    });

    test('middle to first', () {
      expect(reorderedForDrag(abc, 1, 0), ['b', 'a', 'c']);
    });
  });

  group('drags that change nothing', () {
    test('dropping an item back where it started', () {
      expect(reorderedForDrag(abc, 1, 1), abc);
      expect(reorderedForDrag(abc, 1, 2), abc);
    });

    test('a single-item list survives any drag', () {
      expect(reorderedForDrag(['only'], 0, 0), ['only']);
      expect(reorderedForDrag(['only'], 0, 1), ['only']);
    });

    test('an empty list is left alone', () {
      expect(reorderedForDrag(<String>[], 0, 0), isEmpty);
    });
  });

  group('nothing is ever lost', () {
    test('every drag keeps all three groups', () {
      // The failure that would actually cost data: an index slip that drops a
      // group means the product silently stops asking for it at the till.
      for (var from = 0; from < abc.length; from++) {
        for (var to = 0; to <= abc.length; to++) {
          final result = reorderedForDrag(abc, from, to);
          expect(result, hasLength(abc.length),
              reason: 'drag $from → $to changed the count');
          expect(result.toSet(), abc.toSet(),
              reason: 'drag $from → $to lost or duplicated a group');
        }
      }
    });

    test('an out-of-range source is refused, not crashed', () {
      expect(reorderedForDrag(abc, 9, 0), abc);
      expect(reorderedForDrag(abc, -1, 0), abc);
    });

    test('an out-of-range target is clamped into the list', () {
      expect(reorderedForDrag(abc, 0, 99), ['b', 'c', 'a']);
    });
  });

  test('it works on the int ids the picker actually passes', () {
    // The real payload: group ids, whose order is written straight to
    // product_modifier_groups.rank.
    expect(reorderedForDrag([10, 20, 30], 0, 3), [20, 30, 10]);
  });
}
