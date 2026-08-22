import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to `legacy` in Riverpod 3; the rest of this app's simple
// UI-preference providers import it from here too.
import 'package:flutter_riverpod/legacy.dart';

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

/// Per-table column widths, keyed by a table id.
///
/// In memory only, deliberately — matching the column-visibility providers
/// beside it. A width is a per-sitting preference; persisting it is a small
/// follow-up (`shared_preferences`, device-scoped) and not a behaviour anyone
/// is missing today.
final ilyassColumnWidthsProvider =
    StateProvider.family<Map<String, double>, String>(
        (ref, tableId) => const {});

class IlyassTable<T> extends ConsumerStatefulWidget {
  const IlyassTable({
    super.key,
    required this.tableId,
    required this.columns,
    required this.rows,
    this.rowHeight = 56,
    this.headerHeight = 44,
    this.onRowTap,
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

  /// Shown instead of the table when [rows] is empty.
  final Widget? emptyState;

  @override
  ConsumerState<IlyassTable<T>> createState() => _IlyassTableState<T>();
}

class _IlyassTableState<T> extends ConsumerState<IlyassTable<T>> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  /// Applies a drag to one column, clamped so it can never collapse to nothing
  /// or grow past anything usable.
  void _resize(IlyassColumn<T> column, double delta) {
    final widths = ref.read(ilyassColumnWidthsProvider(widget.tableId));
    final current = widths[column.key] ?? column.width;
    final next = (current + delta).clamp(column.minWidth, 900.0);
    ref.read(ilyassColumnWidthsProvider(widget.tableId).notifier).state = {
      ...widths,
      column.key: next,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = widget.columns;

    if (widget.rows.isEmpty && widget.emptyState != null) {
      return widget.emptyState!;
    }
    if (columns.isEmpty) return const SizedBox.shrink();

    final widths = ref.watch(ilyassColumnWidthsProvider(widget.tableId));

    return LayoutBuilder(
      builder: (context, constraints) {
        final effective = [
          for (final c in columns) widths[c.key] ?? c.width,
        ];

        // 🚨 Surplus to ONE column, never spread. Spreading it is exactly how
        // a "massive dead zone" opens between two short columns while the name
        // column that needed the room stays clipped.
        final natural = effective.fold<double>(0, (s, w) => s + w);
        final flexIndex = columns.indexWhere((c) => c.flexible);
        final surplus = constraints.maxWidth - natural;
        if (surplus > 0 && flexIndex >= 0) {
          effective[flexIndex] += surplus;
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
                        onDrag: (delta) => _resize(widget.columns[i], delta),
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
    return _HoverRow(
      onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(row),
      child: DecoratedBox(
        decoration: BoxDecoration(
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
  const _ResizeHandle({required this.onDrag});

  /// Receives the drag in *reading* direction: positive always grows the
  /// column, in Arabic as well as in French.
  final void Function(double delta) onDrag;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) =>
            onDrag(rtl ? -details.delta.dx : details.delta.dx),
        child: SizedBox(
          width: 8,
          child: Center(
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor,
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
