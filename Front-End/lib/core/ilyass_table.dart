import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/settings/settings_provider.dart';

/// The **Ilyass Style** data table: draggable column widths, hard-left labels,
/// hard-right figures, and no dead flex space in between.
///
/// Why this exists rather than Material's [DataTable]:
///
///  * `DataTable` spreads surplus width **equally** across every column, so a
///    date column stretches as much as a customer name and a gap opens in the
///    middle of the row. Here the surplus goes to exactly ONE column, declared
///    with [IlyassColumn.flexible].
///  * `DataTable` has no column resizing at all, and an operator reading long
///    document numbers next to short totals needs it.
///  * `DataTable` builds every row up front. This builds them lazily, which is
///    what keeps a few thousand documents scrolling on a tablet.
///
/// Alignment rule, which is not negotiable: money and counts are
/// [IlyassColumn.numeric] and therefore end-aligned, because a column of
/// totals can only be scanned when the last digits line up.

/// One column of an [IlyassTable].
@immutable
class IlyassColumn<T> {
  const IlyassColumn({
    required this.key,
    required this.label,
    required this.cell,
    this.width = 160,
    this.minWidth = 64,
    this.numeric = false,
    this.resizable = true,
    this.flexible = false,
  });

  /// Stable identity, used as the width-map key. Must NOT be a translated
  /// string, or the widths reset when the language changes.
  final String key;

  /// Header text, already translated.
  final String label;

  /// Builds one cell. Keep it cheap — it runs per visible row.
  final Widget Function(BuildContext context, T row) cell;

  /// Starting width in logical pixels, before any drag.
  final double width;

  /// How far a drag may shrink this column.
  final double minWidth;

  /// End-aligns the header and the cell. Money, quantities, counts.
  final bool numeric;

  /// False for an actions column: it holds fixed-size icons, and a dragged-out
  /// actions column is pure dead space.
  final bool resizable;

  /// The one column that absorbs surplus width when the table is narrower than
  /// its pane. Mark exactly one — with none, the table simply stops short of
  /// the right edge; with several, only the first is used.
  final bool flexible;
}

/// Where one table's column widths live on this device.
///
/// Device-scoped, like the printer name and the column-visibility sets: a
/// width is how one operator likes THEIR screen, not company data, so it never
/// syncs and never follows the login.
String ilyassTableWidthsKey(String tableId) => 'ilyass.table.widths.$tableId';

class IlyassTable<T> extends ConsumerStatefulWidget {
  const IlyassTable({
    super.key,
    required this.tableId,
    required this.columns,
    required this.rows,
    this.rowHeight = 56,
    this.headerHeight = 44,
    this.onRowTap,
    this.isRowSelected,
    this.emptyState,
  });

  /// Identifies this table's width preferences. One per screen.
  final String tableId;

  /// Visible columns, in display order. Filter the hidden ones out before
  /// passing them — the table renders exactly what it is given.
  final List<IlyassColumn<T>> columns;

  final List<T> rows;
  final double rowHeight;
  final double headerHeight;
  final void Function(T row)? onRowTap;

  /// Marks the row a master/detail pane is currently showing. Kept as a
  /// predicate rather than an index so the highlight follows the row's own
  /// identity through a re-sort or a refresh.
  final bool Function(T row)? isRowSelected;

  /// Shown instead of the table when [rows] is empty.
  final Widget? emptyState;

  @override
  ConsumerState<IlyassTable<T>> createState() => _IlyassTableState<T>();
}

class _IlyassTableState<T> extends ConsumerState<IlyassTable<T>> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  /// Explicit per-column widths. Empty until the operator drags something or a
  /// saved layout is restored.
  Map<String, double> _widths = {};

  /// The column currently under the pointer, and the two numbers the drag is
  /// measured against.
  String? _draggingKey;
  double _dragStartWidth = 0;
  double _dragStartX = 0;

  /// The flexible column's rendered width, held still while a drag is running.
  double? _pinnedFlexWidth;

  static const double _maxColumnWidth = 900;

  @override
  void initState() {
    super.initState();
    _widths = _loadWidths();
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Reads the saved layout. Missing preferences are not an error: this widget
  /// has to render in a test or a preview where nothing overrode the store.
  Map<String, double> _loadWidths() {
    try {
      final raw = ref
          .read(sharedPreferencesProvider)
          .getString(ilyassTableWidthsKey(widget.tableId));
      if (raw == null || raw.isEmpty) return {};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) '${entry.key}': (entry.value as num).toDouble(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Written once per drag, on release — not on every frame of it.
  void _saveWidths() {
    try {
      ref.read(sharedPreferencesProvider).setString(
            ilyassTableWidthsKey(widget.tableId),
            jsonEncode(_widths),
          );
    } catch (_) {
      // No store wired up; the layout still works for this sitting.
    }
  }

  // ── Resizing ──────────────────────────────────────────────────────────────

  /// 🚨 Pins the flexible column for the duration of the drag.
  ///
  /// That column absorbs surplus width, so without this it moves by exactly
  /// what the dragged column gives up. Sitting to the LEFT of the handle —
  /// Customer before Date, as on both screens that use this — the left half of
  /// the table slides while you pull a right edge, and the handle travels out
  /// from under the pointer, which feeds back into the next frame as jitter.
  ///
  /// Pinned in a transient field rather than written into [_widths]: the
  /// flexible column's width is DERIVED, and storing a value the operator never
  /// chose would persist it and stop that column ever filling again. When the
  /// drag ends it resumes absorbing — one clean settle on release instead of a
  /// continuous slide under the finger.
  void _beginResize(
    IlyassColumn<T> column,
    List<double> effective,
    DragStartDetails details,
  ) {
    final flexIndex = widget.columns.indexWhere((c) => c.flexible);

    setState(() {
      _pinnedFlexWidth = flexIndex >= 0 ? effective[flexIndex] : null;
      _draggingKey = column.key;
      _dragStartWidth = effective[widget.columns.indexOf(column)];
      _dragStartX = details.globalPosition.dx;
    });
  }

  /// 🚨 Measured from where the drag STARTED, never accumulated frame by frame.
  ///
  /// Summing `details.delta.dx` drifts as soon as the width clamps: the pointer
  /// keeps travelling while the column has stopped, and on the way back the
  /// column starts moving immediately, so the edge no longer sits under the
  /// finger. Anchoring to the start position makes the edge track the pointer
  /// exactly, and makes a clamp feel like a wall instead of a rubber band.
  void _updateResize(IlyassColumn<T> column, DragUpdateDetails details) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final travelled =
        (details.globalPosition.dx - _dragStartX) * (rtl ? -1 : 1);
    final next = (_dragStartWidth + travelled)
        .clamp(column.minWidth, _maxColumnWidth);

    if (_widths[column.key] == next) return;
    setState(() => _widths = {..._widths, column.key: next});
  }

  void _endResize() {
    if (_draggingKey == null) return;

    // 🚨 The pin is KEPT, as an explicit width for the flexible column.
    //
    // Releasing it would re-derive that column from the surplus, so widening
    // one column would shrink it by the same amount the moment you let go —
    // the same "I pulled the right edge and the left side moved" complaint,
    // just deferred by one frame. Once the operator has sized a column by
    // hand, the table grows past its pane and scrolls instead.
    //
    // It stays a FILLING column: the surplus rule still adds to this value, so
    // giving width back (or opening a wider window) is absorbed here as before.
    final flexIndex = widget.columns.indexWhere((c) => c.flexible);
    final pinned = _pinnedFlexWidth;

    setState(() {
      if (pinned != null && flexIndex >= 0) {
        _widths = {..._widths, widget.columns[flexIndex].key: pinned};
      }
      _draggingKey = null;
      _pinnedFlexWidth = null;
    });
    _saveWidths();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = widget.columns;

    if (widget.rows.isEmpty && widget.emptyState != null) {
      return widget.emptyState!;
    }
    if (columns.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final effective = [
          for (final c in columns) _widths[c.key] ?? c.width,
        ];

        // 🚨 Surplus to ONE column, never spread. Spreading it is exactly how
        // a "massive dead zone" opens between two short columns while the name
        // column that needed the room stays clipped.
        final flexIndex = columns.indexWhere((c) => c.flexible);
        if (flexIndex >= 0) {
          if (_pinnedFlexWidth != null) {
            // A drag is running: hold this column exactly where it is.
            effective[flexIndex] = _pinnedFlexWidth!;
          } else {
            final natural = effective.fold<double>(0, (s, w) => s + w);
            final surplus = constraints.maxWidth - natural;
            if (surplus > 0) effective[flexIndex] += surplus;
          }
        }

        final tableWidth = effective.fold<double>(0, (s, w) => s + w);

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: tableWidth > constraints.maxWidth,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _header(theme, effective),
                  Divider(height: 1, thickness: 1, color: theme.dividerColor),
                  // The header sits OUTSIDE this scroll view, so it stays put
                  // while the rows move — the whole point of a wide table.
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      child: ListView.builder(
                        controller: _vertical,
                        itemExtent: widget.rowHeight,
                        itemCount: widget.rows.length,
                        itemBuilder: (context, index) => _row(
                          theme,
                          effective,
                          widget.rows[index],
                          index,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(ThemeData theme, List<double> effective) {
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      letterSpacing: 0.4,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      height: widget.headerHeight,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            SizedBox(
              width: effective[i],
              child: Stack(
                children: [
                  Align(
                    alignment: widget.columns[i].numeric
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        widget.columns[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ),
                  if (widget.columns[i].resizable &&
                      i != widget.columns.length - 1)
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      child: _ResizeHandle(
                        active: _draggingKey == widget.columns[i].key,
                        onStart: (details) =>
                            _beginResize(widget.columns[i], effective, details),
                        onUpdate: (details) =>
                            _updateResize(widget.columns[i], details),
                        onEnd: _endResize,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, List<double> effective, T row, int index) {
    final selected = widget.isRowSelected?.call(row) ?? false;
    return _HoverRow(
      onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(row),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The selected row keeps its tint under the hover highlight, so
          // moving the pointer never hides which row the detail pane is showing.
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : null,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < widget.columns.length; i++)
              SizedBox(
                width: effective[i],
                child: Align(
                  alignment: widget.columns[i].numeric
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: widget.columns[i].cell(context, row),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 8px grab strip between two header cells.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.active,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  /// True while this handle owns the drag — it thickens and takes the accent
  /// colour, so there is no doubt which edge is moving.
  final bool active;

  final void Function(DragStartDetails) onStart;
  final void Function(DragUpdateDetails) onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: onStart,
        onHorizontalDragUpdate: onUpdate,
        onHorizontalDragEnd: (_) => onEnd(),
        // A cancelled drag has to release the freeze too, or the flexible
        // column never resumes filling the pane.
        onHorizontalDragCancel: onEnd,
        child: SizedBox(
          // Wide enough to grab with a finger, narrow enough not to eat the
          // header label beside it.
          width: 10,
          child: Center(
            child: Container(
              width: active ? 2 : 1,
              color: active
                  ? cs.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that lights up under the pointer — a wide table is unreadable without
/// something tying the far-left label to the far-right figure.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ColoredBox(
          color: _hovering
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
