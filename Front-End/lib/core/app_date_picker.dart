import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// App-wide date / date-range / date-time pickers.
///
/// One visual language for every date selection in the app:
///  * [showAppDateRangePicker] and [showAppDatePicker] render the "Sales history"
///    style calendar (predefined periods + a themed month grid). Use these
///    whenever a **date only** (no time) is being chosen — searches, filters,
///    document dates, due dates.
///  * [showAppDateTimePicker] is the Material date-then-time flow. Use it only
///    when a **date and a time together** are needed in a single action.
///
/// Standalone time-only selection still uses the framework `showTimePicker`
/// (the same Material look this file's date-time flow ends with), so there is
/// nothing to wrap for that case.

final DateTime _kDefaultFirstDate = DateTime(2000);
final DateTime _kDefaultLastDate = DateTime(2100);

/// Themed range picker: predefined periods on the left, a range calendar on the
/// right. Returns the chosen range, or `null` if cancelled.
Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  required DateTime initialStart,
  required DateTime initialEnd,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _AppDatePickerDialog(
      rangeMode: true,
      initialStart: initialStart,
      initialEnd: initialEnd,
      firstDate: firstDate ?? _kDefaultFirstDate,
      lastDate: lastDate ?? _kDefaultLastDate,
    ),
  );
}

/// Themed single-date picker (same calendar as the range picker, without the
/// range band or the period presets). Returns the chosen date, or `null`.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _AppDatePickerDialog(
      rangeMode: false,
      initialStart: initialDate,
      firstDate: firstDate ?? _kDefaultFirstDate,
      lastDate: lastDate ?? _kDefaultLastDate,
    ),
  );
}

/// Date + time in one flow (Material date picker → Material time picker),
/// combined into a single [DateTime]. Cancelling the date step aborts and
/// returns `null`; cancelling only the time step keeps the initial time-of-day
/// so the picked date is still returned.
Future<DateTime?> showAppDateTimePicker(
  BuildContext context, {
  required DateTime initialDateTime,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initialDateTime,
    firstDate: firstDate ?? _kDefaultFirstDate,
    lastDate: lastDate ?? _kDefaultLastDate,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDateTime),
  );
  final tod = time ?? TimeOfDay.fromDateTime(initialDateTime);
  return DateTime(date.year, date.month, date.day, tod.hour, tod.minute);
}

// ── Implementation ──────────────────────────────────────────────────────────

class _DatePreset {
  final String label;
  final DateTime start;
  final DateTime end;
  const _DatePreset(this.label, this.start, this.end);
}

class _AppDatePickerDialog extends ConsumerStatefulWidget {
  final bool rangeMode;
  final DateTime initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  const _AppDatePickerDialog({
    required this.rangeMode,
    required this.initialStart,
    this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  ConsumerState<_AppDatePickerDialog> createState() =>
      _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends ConsumerState<_AppDatePickerDialog> {
  late DateTime _start;
  late DateTime? _end; // range mode only
  late DateTime _viewMonth;
  bool _pickingEnd = false;

  /// Column headers for the calendar grid, MONDAY first — the grid is built
  /// from `_weekStart`, which is Monday-based, so the order is load-bearing and
  /// a locale must not re-sort its week.
  List<String> get _dayLabels =>
      AppLocalizations.of(context).weekdayInitials.split(',');

  static DateTime _d(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static DateTime _today() => _d(DateTime.now());

  static DateTime _weekStart(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));
  static DateTime _weekEnd(DateTime d) => d.add(Duration(days: 7 - d.weekday));

  DateTime get _firstDay => _d(widget.firstDate);
  DateTime get _lastDay => _d(widget.lastDate);

  DateTime _clamp(DateTime day) {
    if (day.isBefore(_firstDay)) return _firstDay;
    if (day.isAfter(_lastDay)) return _lastDay;
    return day;
  }

  bool _inBounds(DateTime day) =>
      !day.isBefore(_firstDay) && !day.isAfter(_lastDay);

  @override
  void initState() {
    super.initState();
    _start = _clamp(_d(widget.initialStart));
    _end = widget.rangeMode
        ? _clamp(_d(widget.initialEnd ?? widget.initialStart))
        : null;
    _viewMonth = DateTime(_start.year, _start.month);
  }

  List<_DatePreset> _presets() {
    final l10n = AppLocalizations.of(context);
    final now = _today();
    final wS = _weekStart(now);
    final lwS = _weekStart(now.subtract(const Duration(days: 7)));
    return [
      _DatePreset(l10n.today, now, now),
      _DatePreset(
        l10n.yesterday,
        now.subtract(const Duration(days: 1)),
        now.subtract(const Duration(days: 1)),
      ),
      _DatePreset(l10n.thisWeek, wS, _weekEnd(now)),
      _DatePreset(l10n.lastWeek, lwS, _weekEnd(lwS)),
      _DatePreset(
        l10n.thisMonth,
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 0),
      ),
      _DatePreset(
        l10n.lastMonth,
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 0),
      ),
      _DatePreset(
          l10n.thisYear, DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
      _DatePreset(
        l10n.lastYear,
        DateTime(now.year - 1, 1, 1),
        DateTime(now.year - 1, 12, 31),
      ),
    ];
  }

  void _applyPreset(_DatePreset p) => setState(() {
    // Keep presets inside the caller's bounds (e.g. a filter capped at "today"
    // shouldn't let "This year" run to Dec 31).
    _start = _clamp(p.start);
    _end = _clamp(p.end);
    if (_end!.isBefore(_start)) _end = _start;
    _pickingEnd = false;
    _viewMonth = DateTime(_start.year, _start.month);
  });

  void _onDayTap(DateTime day) {
    if (!_inBounds(day)) return;
    setState(() {
      if (!widget.rangeMode) {
        _start = day;
        return;
      }
      if (!_pickingEnd || _end != null) {
        _start = day;
        _end = null;
        _pickingEnd = true;
      } else {
        if (day.isBefore(_start)) {
          _start = day;
          _end = null;
        } else {
          _end = day;
          _pickingEnd = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: widget.rangeMode ? 580 : 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.rangeMode) ...[
                    _buildPresetPanel(theme, cs),
                    VerticalDivider(
                      width: 1,
                      color: theme.dividerColor,
                      thickness: 0.5,
                    ),
                  ],
                  Expanded(child: _buildCalendar(theme, cs)),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor, thickness: 0.5),
            _buildFooter(theme, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetPanel(ThemeData theme, ColorScheme cs) {
    final presets = _presets();
    return SizedBox(
      width: 238,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).predefinedPeriod,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate((presets.length / 2).ceil(), (row) {
              final a = presets[row * 2];
              final b = row * 2 + 1 < presets.length ? presets[row * 2 + 1] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: _presetBtn(cs, a)),
                    if (b != null) ...[
                      const SizedBox(width: 6),
                      Expanded(child: _presetBtn(cs, b)),
                    ] else
                      const Expanded(child: SizedBox()),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, ColorScheme cs) {
    final fmt = ref.watch(appDateFormatProvider).date;
    final firstOfView = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final canGoPrev =
        firstOfView.isAfter(DateTime(_firstDay.year, _firstDay.month, 1));
    final canGoNext =
        firstOfView.isBefore(DateTime(_lastDay.year, _lastDay.month, 1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _navBtn(
                Icons.chevron_left,
                canGoPrev
                    ? () => setState(() {
                        _viewMonth =
                            DateTime(_viewMonth.year, _viewMonth.month - 1);
                      })
                    : null,
              ),
              Expanded(
                child: Text(
                  // Deliberately NOT the company's date format: this is the
                  // calendar's month HEADING ("September 2026"), a month name
                  // rather than a date. Running it through `AppDateFormat`
                  // would print "09/2026" over the grid.
                  DateFormat('MMMM yyyy').format(_viewMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _navBtn(
                Icons.chevron_right,
                canGoNext
                    ? () => setState(() {
                        _viewMonth =
                            DateTime(_viewMonth.year, _viewMonth.month + 1);
                      })
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _dayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          _buildGrid(cs),
          const SizedBox(height: 10),
          Center(
            child: Text(
              widget.rangeMode
                  ? (_end != null
                        ? '${fmt.format(_start)}  →  ${fmt.format(_end!)}'
                        : _pickingEnd
                        ? AppLocalizations.of(context).nowSelectEndDate
                        : fmt.format(_start))
                  : fmt.format(_start),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: (!widget.rangeMode || _end != null || !_pickingEnd)
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (!widget.rangeMode)
            TextButton(
              onPressed: _inBounds(_today())
                  ? () => setState(() {
                      _start = _today();
                      _viewMonth = DateTime(_start.year, _start.month);
                    })
                  : null,
              child: Text(AppLocalizations.of(context).today),
            ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 14),
            label: Text(AppLocalizations.of(context).actionCancel),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: () {
              if (widget.rangeMode) {
                Navigator.pop(
                  context,
                  DateTimeRange(start: _start, end: _end ?? _start),
                );
              } else {
                Navigator.pop(context, _start);
              }
            },
            icon: const Icon(Icons.check, size: 14),
            label: Text(AppLocalizations.of(context).actionOk),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetBtn(ColorScheme cs, _DatePreset p) {
    // Highlight the preset whose (bounds-clamped) range matches the selection.
    final pStart = _clamp(p.start);
    var pEnd = _clamp(p.end);
    if (pEnd.isBefore(pStart)) pEnd = pStart;
    final isActive = _start == pStart && _end == pEnd;
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: () => _applyPreset(p),
        style: OutlinedButton.styleFrom(
          foregroundColor: isActive ? cs.onPrimary : cs.onSurface,
          backgroundColor: isActive ? cs.primary : null,
          side: BorderSide(
            color: isActive ? cs.primary : cs.outlineVariant,
            width: 0.8,
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          p.label,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(
        icon,
        size: 18,
        color: onTap == null
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)
            : null,
      ),
    ),
  );

  Widget _buildGrid(ColorScheme cs) {
    final now = _today();
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startOff = firstDay.weekday - 1;
    final totalCells = startOff + lastDay.day;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(
        rows,
        (r) => Row(
          children: List.generate(7, (c) {
            final idx = r * 7 + c;
            final dayNum = idx - startOff + 1;
            if (dayNum < 1 || dayNum > lastDay.day) {
              return const Expanded(child: SizedBox(height: 32));
            }
            final date = DateTime(_viewMonth.year, _viewMonth.month, dayNum);
            return Expanded(child: _buildDay(cs, date, now));
          }),
        ),
      ),
    );
  }

  Widget _buildDay(ColorScheme cs, DateTime date, DateTime now) {
    final disabled = !_inBounds(date);
    final isStart = date == _start;
    final isEnd = _end != null && date == _end;
    final inRange = _end != null && date.isAfter(_start) && date.isBefore(_end!);
    final isToday = date == now;
    final isSel = isStart || isEnd;

    BoxDecoration rangeDeco = const BoxDecoration();
    if (inRange) {
      rangeDeco = BoxDecoration(color: cs.primary.withValues(alpha: 0.15));
    } else if (_end != null && (isStart || isEnd)) {
      rangeDeco = BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(16) : Radius.zero,
          right: isEnd ? const Radius.circular(16) : Radius.zero,
        ),
      );
    }

    return GestureDetector(
      onTap: disabled ? null : () => _onDayTap(date),
      child: Container(
        height: 32,
        decoration: rangeDeco,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSel ? cs.primary : null,
              border: isToday && !isSel
                  ? Border.all(color: cs.primary, width: 1.2)
                  : null,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : null,
                  color: disabled
                      ? cs.onSurface.withValues(alpha: 0.25)
                      : isSel
                      ? cs.onPrimary
                      : isToday
                      ? cs.primary
                      : cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
