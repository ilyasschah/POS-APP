import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/reorder.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/settings/settings_provider.dart';

/// Column ORDER for the tables built on `IlyassTable`, and the modal that
/// edits it.
///
/// Order is a Riverpod provider while width is widget-local state, and the
/// split is not arbitrary: a width is only ever changed by the table itself
/// (dragging its own header), whereas the order is changed from a dialog that
/// is a different route entirely. The table has to hear about that while it is
/// off screen, which is what a provider is for.

/// Where one table's column order lives on this device.
///
/// A SIBLING of `ilyassTableWidthsKey`, not a field inside it. The widths blob
/// is owned by the table widget and rewritten on every drag release; the order
/// is owned by this notifier and rewritten from the picker. Two writers on one
/// key is a lost update waiting to happen — resize a column, reorder, resize
/// again, and one of the two changes is gone.
String ilyassTableOrderKey(String tableId) => 'ilyass.table.order.$tableId';

const String _orderKeyPrefix = 'ilyass.table.order.';

/// Every table's column order, keyed by `tableId`. A table absent from the map
/// has never been reordered and renders in the order its screen declares.
///
/// Device-scoped, like the widths and the visible-column sets: which order one
/// operator likes on THEIR screen is not company data, so it never syncs and
/// never follows the login.
final ilyassColumnOrderProvider =
    NotifierProvider<IlyassColumnOrderNotifier, Map<String, List<String>>>(
  IlyassColumnOrderNotifier.new,
);

class IlyassColumnOrderNotifier extends Notifier<Map<String, List<String>>> {
  /// Hydrated in one pass by sweeping the preference keys rather than lazily
  /// per table: a lazy read would have to write state during a widget build,
  /// which Riverpod rightly refuses.
  @override
  Map<String, List<String>> build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith(_orderKeyPrefix))
            key.substring(_orderKeyPrefix.length):
                prefs.getStringList(key) ?? const <String>[],
      };
    } catch (_) {
      // No store wired up — a test, or a preview. The tables still render in
      // their declared order.
      return {};
    }
  }

  List<String> orderFor(String tableId) => state[tableId] ?? const <String>[];

  /// [keys] is the FULL catalogue in its new order, hidden columns included.
  /// Storing only the visible ones would drop a hidden column's position, so
  /// switching it back on would fling it to the end of the table.
  void setOrder(String tableId, List<String> keys) {
    state = {...state, tableId: List<String>.unmodifiable(keys)};
    try {
      ref
          .read(sharedPreferencesProvider)
          .setStringList(ilyassTableOrderKey(tableId), keys);
    } catch (_) {
      // The order still holds for this sitting.
    }
  }

  /// Back to the order the screen declares.
  void reset(String tableId) {
    state = {...state}..remove(tableId);
    try {
      ref.read(sharedPreferencesProvider).remove(ilyassTableOrderKey(tableId));
    } catch (_) {
      // Nothing to forget.
    }
  }
}

/// Reorders [items] to match [order], a list of column keys.
///
/// 🚨 Anything [order] does not mention keeps the position it DECLARES. A
/// column added in a later app version therefore lands where its screen put it
/// instead of being exiled to the far right of a layout saved before it
/// existed — and the same rule is what keeps a table's leading checkbox column
/// leading, since it is not in the picker's catalogue and so never appears in
/// a saved order.
List<T> ilyassApplyColumnOrder<T>(
  List<T> items,
  List<String> order,
  String Function(T item) keyOf,
) {
  if (order.isEmpty) return items;

  final pending = <String, T>{for (final item in items) keyOf(item): item};
  final result = <T>[];

  for (final key in order) {
    if (!pending.containsKey(key)) continue;
    result.add(pending.remove(key) as T);
  }

  for (var i = 0; i < items.length; i++) {
    final key = keyOf(items[i]);
    if (!pending.containsKey(key)) continue;
    pending.remove(key);
    result.insert(math.min(i, result.length), items[i]);
  }

  return result;
}

/// One row of the column picker.
@immutable
class IlyassPickerColumn {
  const IlyassPickerColumn({
    required this.key,
    required this.label,
    this.mandatory = false,
  });

  /// Matches `IlyassColumn.key` — the stable, untranslated identity.
  final String key;

  /// Already translated.
  final String label;

  /// Cannot be switched off. It can still be DRAGGED: being unable to hide the
  /// product name is no reason to be unable to move it.
  final bool mandatory;
}

/// The "Show / Hide Columns" modal: a checkbox and a drag handle per column.
///
/// Visibility lives with the caller (a provider on one screen, plain widget
/// state on another) and is reached through [isVisible] / [onVisibleChanged],
/// while the ORDER is read and written here. The dialog rebuilds itself after
/// every toggle, so a caller whose closures read live state sees the change
/// immediately without having to tell the dialog how to watch it.
Future<void> showIlyassColumnPicker({
  required BuildContext context,
  required String tableId,
  required List<IlyassPickerColumn> columns,
  required bool Function(String key) isVisible,
  required void Function(String key, bool visible) onVisibleChanged,
  String? title,
  VoidCallback? onReset,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _IlyassColumnPickerDialog(
      tableId: tableId,
      columns: columns,
      isVisible: isVisible,
      onVisibleChanged: onVisibleChanged,
      title: title,
      onReset: onReset,
    ),
  );
}

class _IlyassColumnPickerDialog extends ConsumerStatefulWidget {
  const _IlyassColumnPickerDialog({
    required this.tableId,
    required this.columns,
    required this.isVisible,
    required this.onVisibleChanged,
    this.title,
    this.onReset,
  });

  final String tableId;
  final List<IlyassPickerColumn> columns;
  final bool Function(String key) isVisible;
  final void Function(String key, bool visible) onVisibleChanged;
  final String? title;
  final VoidCallback? onReset;

  @override
  ConsumerState<_IlyassColumnPickerDialog> createState() =>
      _IlyassColumnPickerDialogState();
}

class _IlyassColumnPickerDialogState
    extends ConsumerState<_IlyassColumnPickerDialog> {
  void _toggle(String key, bool value) {
    widget.onVisibleChanged(key, value);
    // The caller owns the visibility state and may well be a different route's
    // widget — rebuild so the checkboxes re-read it.
    setState(() {});
  }

  void _reorder(List<IlyassPickerColumn> shown, int oldIndex, int newIndex) {
    final next = reorderedForDrag(shown, oldIndex, newIndex);
    ref
        .read(ilyassColumnOrderProvider.notifier)
        .setOrder(widget.tableId, [for (final c in next) c.key]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final order = ref.watch(ilyassColumnOrderProvider)[widget.tableId] ??
        const <String>[];
    final shown =
        ilyassApplyColumnOrder(widget.columns, order, (c) => c.key);

    final visibleCount = widget.columns.where((c) => isOn(c)).length;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(widget.title ?? l.showHideColumns),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: context.dialogWidth(380),
        // ReorderableListView needs a bounded height, and a catalogue of
        // twenty columns must not push the buttons off a short screen.
        height: math.min(
          shown.length * 60.0 + 8,
          context.dialogMaxHeight(fraction: 0.55),
        ),
        child: ReorderableListView.builder(
          // Handles are explicit: the whole row must stay tappable for the
          // checkbox, and a long-press-to-drag row on a touch screen fights
          // with the scroll.
          buildDefaultDragHandles: false,
          itemCount: shown.length,
          // Deliberately the deprecated `onReorder`, not `onReorderItem`: the
          // replacement pre-adjusts newIndex, which would double-correct the
          // off-by-one that `reorderedForDrag` already handles for every
          // reorderable list in the app. Both lists move to the new callback
          // together or neither does.
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) =>
              _reorder(shown, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final col = shown[index];
            final on = isOn(col);
            // A table with nothing in it is not a table. The last column
            // standing locks on the same way a mandatory one does.
            final locked = col.mandatory || (on && visibleCount <= 1);

            return ListTile(
              key: ValueKey(col.key),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Checkbox(
                value: on,
                onChanged: locked ? null : (v) => _toggle(col.key, v ?? false),
              ),
              title: Text(col.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: col.mandatory ? Text(l.alwaysShown) : null,
              // Tapping the row toggles too — a 380px-wide row whose only
              // target is a 24px box is a miss waiting to happen.
              onTap: locked ? null : () => _toggle(col.key, !on),
              trailing: ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: l.dragToReorderColumns,
                  child: Padding(
                    // Finger-sized: this is the control the whole feature is
                    // driven by on a tablet.
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: Icon(Icons.drag_indicator,
                        color: theme.colorScheme.outline),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Reset means the whole layout, not half of it: a restored
            // visibility set in a hand-made order is neither of the two
            // states the operator was asking for.
            widget.onReset?.call();
            ref.read(ilyassColumnOrderProvider.notifier).reset(widget.tableId);
            setState(() {});
          },
          child: Text(l.actionReset),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.actionClose),
        ),
      ],
    );
  }

  bool isOn(IlyassPickerColumn col) =>
      col.mandatory || widget.isVisible(col.key);
}
