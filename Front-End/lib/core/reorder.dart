/// Moves the item at [oldIndex] to [newIndex] the way a drag reports it.
///
/// 🚨 `ReorderableListView` reports the destination as an index in the list
/// BEFORE the dragged item is removed, so anything dragged DOWNWARD arrives one
/// position too far. Every reorderable list has to correct for it, and getting
/// it wrong is invisible on the first drag — it only shows up when an item
/// dragged to the end lands second-from-last.
///
/// Extracted from the widget so the arithmetic can be tested without a gesture,
/// and kept in `core` because both the modifier-group list and the column
/// picker drag things for a living. One copy, one off-by-one to get right.
List<T> reorderedForDrag<T>(List<T> items, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= items.length) return List<T>.from(items);

  final next = List<T>.from(items);
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  target = target.clamp(0, next.length - 1);

  next.insert(target, next.removeAt(oldIndex));
  return next;
}
