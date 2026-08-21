/// Helpers for building `DropdownButton` option lists that cannot trip its
/// "there should be exactly one item with [DropdownButton]'s value" assertion.
///
/// That assertion is unforgiving and takes the whole dialog down with a red
/// screen, and this codebase has hit it repeatedly for the same two reasons:
///
///  1. **Identity equality.** Domain objects here (`FloorPlanTable`, `User`,
///     `Customer`) declare no `==`, so Dart compares them by identity. A value
///     seeded in `initState` from a `ref.read(...)` snapshot is a DIFFERENT
///     instance from the one a later provider emission puts in the item list —
///     same row, same id, zero matches. Guarding by id while still handing the
///     widget the stale OBJECT (as the transfer dialog did) fixes nothing.
///  2. **Duplicates.** Two items sharing a value trips the identical assert
///     from the other direction.
///
/// [dropdownOptionsById] removes both by keying the dropdown on the entity's
/// **id** — ints compare by value — and returning a de-duplicated option list
/// plus a value guaranteed to appear in it.
library;

/// Resolves [selected] against [available] for an id-keyed dropdown.
///
/// Returns the options to render and the safe initial value:
///  • [selected] is unioned in when [available] doesn't contain its id, so a
///    row that is filtered out of the list — an order's own (occupied) table,
///    a since-disabled staff member — can still be displayed as the current
///    choice instead of crashing the dialog.
///  • options are de-duplicated by id, first occurrence winning.
///  • `value` is null unless that exact id survives into the options.
({List<T> options, int? value}) dropdownOptionsById<T>(
  List<T> available,
  T? selected,
  int Function(T) idOf,
) {
  final selectedId = selected == null ? null : idOf(selected);

  final merged = <T>[
    ...available,
    if (selected != null && !available.any((e) => idOf(e) == selectedId))
      selected,
  ];

  final seen = <int>{};
  final options = merged.where((e) => seen.add(idOf(e))).toList();

  return (
    options: options,
    value: options.any((e) => idOf(e) == selectedId) ? selectedId : null,
  );
}
