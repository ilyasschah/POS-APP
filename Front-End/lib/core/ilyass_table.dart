import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/ilyass_column_order.dart';
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
///
/// ## The width model
///
/// Every column is ultimately a **fixed pixel width**. [IlyassColumn.flexible]
/// is a STARTING state, not a permanent one: it says "absorb whatever the pane
/// has spare until somebody decides otherwise".
///
/// The moment a resize handle is grabbed, every column is measured and written
/// down in pixels — flex-to-fixed conversion — so from that frame on the grid
/// is a plain fixed-width table. That is what makes the flexible column itself
/// draggable: while a layout pass is free to recompute it, a drag and the
/// layout engine are two authorities fighting over the same number, and the
/// layout engine wins every frame.
///
/// A column the operator has dragged *directly* is theirs for good — it is
/// recorded in `manual` and never flexes again, on this launch or any later
/// one. A column merely frozen in passing (because a NEIGHBOUR was dragged)
/// goes back to absorbing the surplus once the pointer is released, so
/// narrowing one column does not leave a permanent hole at the right edge.

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
    this.header,
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

  /// Replaces the header TEXT with a widget — the select-all checkbox, and
  /// nothing else so far. [label] is still required: it is what the column
  /// picker and the resize tooltip call this column.
  final Widget Function(BuildContext context)? header;
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
    this.rowColor,
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

  /// Tints one row for a reason of its own — a disabled product, a voided
  /// line. Sits UNDER the selection tint and the hover highlight, so neither
  /// of those is lost on a row that carries it.
  final Color? Function(T row)? rowColor;

  /// Shown instead of the table when [rows] is empty.
  final Widget? emptyState;

  @override
  ConsumerState<IlyassTable<T>> createState() => _IlyassTableState<T>();
}

class _IlyassTableState<T> extends ConsumerState<IlyassTable<T>> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  /// Every column's width in pixels. A column absent from this map has not
  /// been measured yet and falls back to its declared [IlyassColumn.width].
  Map<String, double> _widths = {};

  /// Columns the operator dragged BY THE HANDLE, as opposed to ones frozen in
  /// passing when a neighbour was dragged. Only these opt out of flexing —
  /// see the width model on [IlyassTable].
  Set<String> _manual = {};

  /// The column currently under the pointer, and the two numbers the drag is
  /// measured against.
  String? _draggingKey;
  double _dragStartWidth = 0;
  double _dragStartX = 0;

  /// The floor every column shares, whatever it declares. A column dragged
  /// narrower than this is a column nobody can find the edge of again.
  static const double _absoluteMinWidth = 60;

  /// A runaway-drag guard, not a design limit.
  static const double _maxColumnWidth = 900;

  @override
  void initState() {
    super.initState();
    final (widths, manual) = _loadLayout();
    _widths = widths;
    _manual = manual;
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
  ///
  /// Two shapes are accepted. The current one carries the manual set alongside
  /// the widths; the original was a bare `{key: width}` map, and a layout in
  /// that shape is read as "nothing was sized by hand" — which is exactly how
  /// the version that wrote it behaved.
  (Map<String, double>, Set<String>) _loadLayout() {
    try {
      final raw = ref
          .read(sharedPreferencesProvider)
          .getString(ilyassTableWidthsKey(widget.tableId));
      if (raw == null || raw.isEmpty) return ({}, {});

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ({}, {});

      final widthsRaw =
          decoded['widths'] is Map ? decoded['widths'] as Map : decoded;
      final widths = <String, double>{
        for (final entry in widthsRaw.entries)
          if (entry.value is num)
            '${entry.key}': (entry.value as num).toDouble(),
      };
      final manual = <String>{
        if (decoded['manual'] is List)
          for (final key in decoded['manual'] as List) '$key',
      };
      return (widths, manual);
    } catch (_) {
      return ({}, {});
    }
  }

  /// Written once per drag, on release — not on every frame of it. Encoding
  /// JSON and hitting the preference store 60 times a second is the difference
  /// between a drag that tracks the finger and one that stutters.
  void _saveLayout() {
    try {
      ref.read(sharedPreferencesProvider).setString(
            ilyassTableWidthsKey(widget.tableId),
            jsonEncode({'widths': _widths, 'manual': _manual.toList()}),
          );
    } catch (_) {
      // No store wired up; the layout still works for this sitting.
    }
  }

  // ── Resizing ──────────────────────────────────────────────────────────────

  /// The width every column actually renders at, in pixels, for a pane of
  /// [paneWidth].
  ///
  /// 🚨 The flexible column is skipped while a drag is running or once it has
  /// been sized by hand. Recomputing it during a drag is precisely the bug this
  /// engine was rebuilt to kill: the drag writes a width, the surplus rule
  /// overwrites it on the same frame, and the column sits there refusing to
  /// move no matter how far the handle is pulled.
  List<double> _resolve(double paneWidth, List<IlyassColumn<T>> columns) {
    final resolved = [for (final c in columns) _widths[c.key] ?? c.width];

    final flexIndex = columns.indexWhere((c) => c.flexible);
    if (flexIndex < 0) return resolved;
    if (_draggingKey != null || _manual.contains(columns[flexIndex].key)) {
      return resolved;
    }

    // Surplus to ONE column, never spread. Spreading it is how a dead zone
    // opens between two short columns while the name column that needed the
    // room stays clipped.
    final natural = resolved.fold<double>(0, (sum, w) => sum + w);
    final surplus = paneWidth - natural;
    if (surplus > 0) resolved[flexIndex] += surplus;
    return resolved;
  }

  /// The floor for one column: its own declared minimum, but never under the
  /// table-wide floor.
  double _minWidthOf(IlyassColumn<T> column) =>
      math.max(column.minWidth, _absoluteMinWidth);

  /// 🚨 Flex-to-fixed conversion, and the whole reason a drag is stable.
  ///
  /// Every column is measured at the pixels it currently occupies and written
  /// into [_widths] before a single frame of movement. After this the table is
  /// a plain fixed-width grid: pulling one edge cannot make a neighbour move,
  /// the handle cannot travel out from under the pointer, and the flexible
  /// column — now an ordinary number like any other — can itself be dragged.
  ///
  /// Merged into [_widths] rather than replacing it, so a column the operator
  /// sized and then hid in the column picker keeps its width for when it comes
  /// back.
  ///
  /// [columns] is the list AS RENDERED, which is the order the operator chose
  /// — not `widget.columns`. `resolved` is indexed the same way, so freezing
  /// against the declared order would hand every column its neighbour's width.
  void _beginResize(
    IlyassColumn<T> column,
    List<IlyassColumn<T>> columns,
    List<double> resolved,
    DragStartDetails details,
  ) {
    final index = columns.indexWhere((c) => c.key == column.key);
    if (index < 0) return;

    setState(() {
      _widths = {
        ..._widths,
        for (var i = 0; i < columns.length; i++) columns[i].key: resolved[i],
      };
      _draggingKey = column.key;
      _dragStartWidth = resolved[index];
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
        .clamp(_minWidthOf(column), _maxColumnWidth);

    // A drag that has not moved the column has nothing to repaint — this is
    // what keeps a slow drag from rebuilding the visible rows on every one of
    // the pointer's sub-pixel reports.
    if (_widths[column.key] == next) return;

    setState(() {
      _widths = {..._widths, column.key: next};
      // 🚨 The commitment comes from MOVEMENT, not from touching the handle.
      // Marking it in _beginResize would let a stray click on an edge stop a
      // column filling for good — a change the operator never asked for and
      // cannot see until the window is next resized.
      //
      // Only the column under the handle counts as chosen. The others were
      // frozen in passing and go back to flexing when the pointer lifts.
      if (!_manual.contains(column.key)) _manual = {..._manual, column.key};
    });
  }

  /// Nothing to unwind: the widths in [_widths] are already the truth, and
  /// have been since [_beginResize]. Releasing only stops suppressing the
  /// surplus rule, which lets a column that was frozen in passing take back
  /// whatever the drag freed rather than leaving a hole at the right edge.
  void _endResize() {
    if (_draggingKey == null) return;
    setState(() => _draggingKey = null);
    _saveLayout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 🚨 Watched, not read: the order is changed from the column picker, which
    // is a different route entirely. The table has to hear about that while it
    // is off screen and rebuild in the new order the moment it comes back —
    // and on the screen the picker was opened from, instantly underneath it.
    final columns = ilyassApplyColumnOrder(
      widget.columns,
      ref.watch(ilyassColumnOrderProvider)[widget.tableId] ?? const <String>[],
      (c) => c.key,
    );

    if (widget.rows.isEmpty && widget.emptyState != null) {
      return widget.emptyState!;
    }
    if (columns.isEmpty) return const SizedBox.shrink();

    // 🚨 The LayoutBuilder sits OUTSIDE the horizontal scroll view on purpose.
    // Inside it the incoming width is unbounded, and `constraints.maxWidth`
    // — the number the surplus rule is measured against — would be infinity.
    return LayoutBuilder(
      builder: (context, constraints) {
        final effective = _resolve(constraints.maxWidth, columns);
        final columnsWidth = effective.fold<double>(0, (sum, w) => sum + w);

        // The canvas is free to be wider than the pane: a stretched column
        // pushes the rest of the table off to the trailing edge and the view
        // scrolls to it, which is the alternative to an overflow stripe or a
        // column that simply refuses to grow.
        //
        // It is never NARROWER than the pane, so the header band and the row
        // dividers still reach the edge when the columns stop short of it.
        final canvasWidth = math.max(columnsWidth, constraints.maxWidth);

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: columnsWidth > constraints.maxWidth,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: canvasWidth,
              child: Column(
                children: [
                  _header(theme, columns, effective),
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
                          columns,
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

  Widget _header(
    ThemeData theme,
    List<IlyassColumn<T>> columns,
    List<double> effective,
  ) {
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
          for (var i = 0; i < columns.length; i++)
            SizedBox(
              width: effective[i],
              child: Stack(
                children: [
                  Align(
                    alignment: columns[i].numeric
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: columns[i].header?.call(context) ??
                          Text(
                            columns[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style,
                          ),
                    ),
                  ),
                  // Including the LAST column: its trailing edge is the one
                  // an operator reaches for to widen the table past the pane,
                  // and a fixed-width grid that scrolls has somewhere to put
                  // the result.
                  if (columns[i].resizable)
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      child: _ResizeHandle(
                        active: _draggingKey == columns[i].key,
                        onStart: (details) =>
                            _beginResize(
                                columns[i], columns, effective, details),
                        onUpdate: (details) =>
                            _updateResize(columns[i], details),
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

  Widget _row(
    ThemeData theme,
    List<IlyassColumn<T>> columns,
    List<double> effective,
    T row,
    int index,
  ) {
    final selected = widget.isRowSelected?.call(row) ?? false;
    final tint = widget.rowColor?.call(row);
    return _HoverRow(
      onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(row),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The selected row keeps its tint under the hover highlight, so
          // moving the pointer never hides which row the detail pane is showing.
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : tint,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < columns.length; i++)
              SizedBox(
                width: effective[i],
                child: Align(
                  alignment: columns[i].numeric
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: columns[i].cell(context, row),
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
