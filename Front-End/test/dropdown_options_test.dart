// Regression for the red screen on POS → Transfer (reported 2026-08-15):
//
//   'There should be exactly one item with [DropdownButton]'s value:
//    Instance of 'FloorPlanTable'. Either zero or 2 or more
//    [DropdownMenuItem]s were detected with the same value'
//
// `FloorPlanTable` (like `User` and `Customer`) declares no `==`, so Dart
// compares by IDENTITY. The transfer dialog seeded its value in initState from
// a `ref.read(allRoomsProvider)` snapshot while the items came from a later
// emission of a different provider — same table row, a freshly constructed
// object. The old guard compared IDs but still handed the widget the stale
// OBJECT, so it matched zero items and the assert killed the dialog.
//
// The fixture below reproduces that precisely: `_stale` is a separate instance
// with the same id, and every test asserts through it.
// ignore_for_file: prefer_const_constructors
//
// ⚠️ Do NOT let the linter "fix" these into const constructors. Dart
// canonicalises identical const expressions to the SAME instance, so
// `const _Row(1, 'Table 1')` would BE `t1` — and every test here depends on
// holding a DISTINCT object with the same id, because that stale-instance case
// is the bug. Const would make them pass for the wrong reason.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/dropdown_options.dart';

/// Stands in for FloorPlanTable/User/Customer: an id-bearing domain object
/// with NO `==` override, so `==` is identity — the whole point.
class _Row {
  final int id;
  final String name;
  const _Row(this.id, this.name);
}

void main() {
  const t1 = _Row(1, 'Table 1');
  const t2 = _Row(2, 'Table 2');

  test('the exact crash: a stale instance of a listed row still resolves', () {
    // Same id as t1, different object. `stale == t1` is false.
    final stale = _Row(1, 'Table 1');
    expect(identical(stale, t1), isFalse);

    final r = dropdownOptionsById([t1, t2], stale, (e) => e.id);

    // Resolves to the id, which the options DO contain — exactly one match.
    expect(r.value, 1);
    expect(r.options.length, 2);
    expect(r.options.where((e) => e.id == r.value).length, 1);
  });

  test('a row missing from the list is unioned back in, not dropped', () {
    // The order's own table: occupied (it is holding it), so absent from the
    // free list — but it is the current choice and must stay selectable.
    final own = _Row(9, 'Table 9');

    final r = dropdownOptionsById([t1, t2], own, (e) => e.id);

    expect(r.value, 9);
    expect(r.options.map((e) => e.id), [1, 2, 9]);
    expect(r.options.where((e) => e.id == r.value).length, 1);
  });

  test('duplicates are collapsed — the "2 or more" half of the assert', () {
    final dupe = _Row(1, 'Table 1 again');

    final r = dropdownOptionsById([t1, dupe, t2], t1, (e) => e.id);

    expect(r.options.map((e) => e.id), [1, 2]);
    expect(r.options.where((e) => e.id == r.value).length, 1);
    // First occurrence wins.
    expect(r.options.first.name, 'Table 1');
  });

  test('unioning a row that is ALSO in the list does not duplicate it', () {
    final stale = _Row(2, 'Table 2');

    final r = dropdownOptionsById([t1, t2], stale, (e) => e.id);

    expect(r.options.map((e) => e.id), [1, 2]);
    expect(r.options.where((e) => e.id == r.value).length, 1);
  });

  test('a null selection yields a null value', () {
    final r = dropdownOptionsById<_Row>([t1, t2], null, (e) => e.id);
    expect(r.value, isNull);
    expect(r.options.length, 2);
  });

  test('an empty list with a selection still offers that selection', () {
    final r = dropdownOptionsById(<_Row>[], t1, (e) => e.id);
    expect(r.value, 1);
    expect(r.options.map((e) => e.id), [1]);
  });

  test('empty list and no selection is a valid empty dropdown', () {
    final r = dropdownOptionsById<_Row>([], null, (e) => e.id);
    expect(r.value, isNull);
    expect(r.options, isEmpty);
  });

  test('the invariant holds across every case: value matches 0 or 1 option',
      () {
    final cases = <(List<_Row>, _Row?)>[
      ([t1, t2], t1),
      ([t1, t2], _Row(1, 'stale')),
      ([t1, t2], _Row(9, 'absent')),
      ([t1, _Row(1, 'dupe'), t2], _Row(1, 'stale')),
      ([], t1),
      ([], null),
      ([t1], null),
    ];

    for (final (available, selected) in cases) {
      final r = dropdownOptionsById(available, selected, (e) => e.id);
      final matches = r.options.where((e) => e.id == r.value).length;
      // This is literally what DropdownButton asserts.
      expect(
        r.value == null ? true : matches == 1,
        isTrue,
        reason: 'value ${r.value} matched $matches options',
      );
    }
  });
}
