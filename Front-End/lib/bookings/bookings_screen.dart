import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/bookings/booking_model.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/bookings/bookings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/floor_plan/floor_plan_screen.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/menu/menu_screen.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/document/document_editor_screen.dart';
import 'package:pos_app/document/document_model.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/customer/customer_provider.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double _slotHeight = 64.0;
const double _timeColWidth = 72.0;
const double _staffColWidth = 180.0;
const double _headerRowHeight = 48.0;
const int _dayStart = 8; // 08:00
const int _dayEnd = 24; // midnight
const int _totalSlots = (_dayEnd - _dayStart) * 2; // 32 half-hour slots
const double _totalHeight = _totalSlots * _slotHeight; // 2048px

// ── Status helpers ────────────────────────────────────────────────────────────
// 1=Scheduled, 2=Arrived/Waiting, 3=In Service, 4=Completed & Paid, 5=No Show
const _statusLabels = {
  1: 'Scheduled',
  2: 'Arrived',
  3: 'In Service',
  4: 'Completed',
  5: 'No Show',
};
const _statusColors = {
  1: Colors.blue,
  2: Colors.orange,
  3: Colors.purple,
  4: Colors.green,
  5: Colors.grey,
};

Color _statusColor(int s) => _statusColors[s] ?? Colors.grey;
String _statusLabel(int s) => _statusLabels[s] ?? 'Unknown';

// ── Date helpers ──────────────────────────────────────────────────────────────
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtHeaderDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

String _fmtTime(TimeOfDay t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _fmtDateTime(DateTime dt) => _fmtTime(TimeOfDay.fromDateTime(dt));

enum _PostSaveAction { stay, open }

// ────────────────────────────────────────────────────────────────────────────
// BookingsScreen
// ────────────────────────────────────────────────────────────────────────────
class BookingsScreen extends ConsumerStatefulWidget {
  /// Opens the global navigation drawer (supplied by MainLayout). When null —
  /// e.g. the screen is pushed as a standalone route — the leading hamburger is
  /// hidden, matching the other POS tab screens.
  final VoidCallback? onMenuPressed;

  const BookingsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  bool _alertsShown = false;
  final _calendarScrollController = ScrollController();
  bool _calendarScrolled = false;
  Timer? _nowTimer;

  @override
  void initState() {
    super.initState();
    // Background refresh on open: pull the latest bookings from the server into
    // the local Drift cache. The screen renders immediately from the cache; the
    // stream re-emits if the pull brings new rows. Offline, this no-ops and the
    // existing cache is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBookings());
    // Drives the "current time" indicator line — rebuild every 30s so it slides
    // down as the clock advances. Cheap: build() just re-reads the cached stream.
    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    _calendarScrollController.dispose();
    super.dispose();
  }

  /// Pulls bookings from the server into the local Drift cache. Fire-and-forget
  /// — the Drift-backed [allBookingsProvider] stream re-emits once the rows
  /// land, so there's no manual invalidate. Failures (offline) are swallowed;
  /// the local cache stays on screen.
  void _refreshBookings() {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    ref.read(syncManagerProvider).pullBookings(companyId).catchError((_) {});
  }

  void _maybeShowAlerts(List<Booking> bookings) {
    if (_alertsShown) return;
    final now = DateTime.now();
    final today = bookings.where((b) => isSameDay(b.startTime, now)).toList();

    final arriving = today.where(
      (b) =>
          b.status == 1 &&
          b.startTime.difference(now).inMinutes >= 0 &&
          b.startTime.difference(now).inMinutes <= 15,
    );

    final overstaying = today.where(
      (b) => b.status == 3 && now.isAfter(b.endTime),
    );

    if (arriving.isEmpty && overstaying.isEmpty) return;
    _alertsShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications_active, color: ctx.warningColor),
              const SizedBox(width: 8),
              const Text('Booking Alerts'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...arriving.map(
                (b) => _AlertRow(
                  icon: Icons.schedule,
                  color: ctx.warningColor,
                  message:
                      '${b.reservationName} is arriving soon '
                      '(${_fmtDateTime(b.startTime)}).',
                ),
              ),
              ...overstaying.map(
                (b) => _AlertRow(
                  icon: Icons.timer_off,
                  color: ctx.dangerColor,
                  message:
                      '${b.reservationName}\'s time is up '
                      '(ended ${_fmtDateTime(b.endTime)}).',
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedBookingDateProvider);
    final bookingsAsync = ref.watch(allBookingsProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final roomsAsync = ref.watch(allRoomsProvider);
    final settings = ref.watch(appSettingsProvider.notifier);
    final bs = settings.bookingSettings;
    final resourceMode = bs.resourceMode;
    final timeSnapping = bs.timeSnappingMinutes;
    final defaultDuration = bs.defaultDurationMinutes;

    final isLoading =
        bookingsAsync.isLoading || usersAsync.isLoading || roomsAsync.isLoading;
    final hasError =
        bookingsAsync.hasError || usersAsync.hasError || roomsAsync.hasError;

    return Scaffold(
      body: Column(
        children: [
          // Unified flat top bar (replaces the legacy Material AppBar): title
          // left-middle, the day navigation + "Add Booking" actions pinned right.
          PosTopBar(
            onMenuPressed: widget.onMenuPressed,
            title: const Text(
              'Bookings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.table_restaurant),
                tooltip: 'Floor Plan',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FloorPlanScreen()),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous day',
                onPressed: () =>
                    ref.read(selectedBookingDateProvider.notifier).state =
                        selectedDate.subtract(const Duration(days: 1)),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showAppDatePicker(
                    context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && mounted) {
                    ref.read(selectedBookingDateProvider.notifier).state =
                        picked;
                  }
                },
                child: Text(
                  _fmtHeaderDate(selectedDate),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next day',
                onPressed: () =>
                    ref.read(selectedBookingDateProvider.notifier).state =
                        selectedDate.add(const Duration(days: 1)),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Booking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.successColor,
                    foregroundColor: context.onStatusColor,
                  ),
                  onPressed: isLoading
                      ? null
                      : () => _showAddDialog(
                          context,
                          users:
                              usersAsync.value
                                  ?.where((u) => u.isEnabled)
                                  .toList() ??
                              [],
                          tables: roomsAsync.value ?? [],
                          resourceMode: resourceMode,
                          defaultDurationMinutes: defaultDuration,
                          prefilledDate: selectedDate,
                        ),
                ),
              ),
            ],
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                ? Center(
                    child: Text(
                      'Error loading data: '
                      '${bookingsAsync.error ?? usersAsync.error ?? roomsAsync.error}',
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final allBookings = bookingsAsync.value!;
                      _maybeShowAlerts(allBookings);
                      final staff = usersAsync.value!
                          .where((u) => u.isEnabled)
                          .toList();
                      final tables = roomsAsync.value!;
                      final dayBookings = allBookings
                          .where((b) => isSameDay(b.startTime, selectedDate))
                          .toList();

                      if (!_calendarScrolled) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted || !_calendarScrollController.hasClients) {
                            return;
                          }
                          final now = DateTime.now();
                          final mins = (now.hour - _dayStart) * 60 + now.minute;
                          if (mins > 0) {
                            final offset =
                                (mins / 30) * _slotHeight + _headerRowHeight;
                            final max = _calendarScrollController
                                .position
                                .maxScrollExtent;
                            _calendarScrollController.jumpTo(
                              offset.clamp(0.0, max),
                            );
                          }
                          _calendarScrolled = true;
                        });
                      }

                      return _CalendarView(
                        bookings: dayBookings,
                        staff: staff,
                        tables: tables,
                        resourceMode: resourceMode,
                        timeSnappingMinutes: timeSnapping,
                        selectedDate: selectedDate,
                        scrollController: _calendarScrollController,
                        onEmptySlotTap: (staffMember, table, time) =>
                            _showAddDialog(
                              context,
                              users: staff,
                              tables: tables,
                              resourceMode: resourceMode,
                              defaultDurationMinutes: defaultDuration,
                              prefilledDate: selectedDate,
                              prefilledStaff: staffMember,
                              prefilledTime: time,
                            ),
                        onBookingTap: (booking) => _showDetailDialog(
                          context,
                          booking,
                          staff,
                          tables,
                          resourceMode,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(
    BuildContext context, {
    required List<User> users,
    required List<FloorPlanTable> tables,
    required String resourceMode,
    required int defaultDurationMinutes,
    required DateTime prefilledDate,
    User? prefilledStaff,
    TimeOfDay? prefilledTime,
  }) {
    showDialog(
      context: context,
      builder: (_) => _AddBookingDialog(
        users: users,
        tables: tables,
        resourceMode: resourceMode,
        date: prefilledDate,
        prefilledStaff: prefilledStaff,
        prefilledTime: prefilledTime,
        defaultDurationMinutes: defaultDurationMinutes,
        onSaved: _refreshBookings,
      ),
    );
  }

  void _showDetailDialog(
    BuildContext context,
    Booking booking,
    List<User> staff,
    List<FloorPlanTable> tables,
    String resourceMode,
  ) {
    showDialog(
      context: context,
      builder: (_) => _BookingDetailDialog(
        booking: booking,
        staff: staff,
        tables: tables,
        resourceMode: resourceMode,
        onUpdated: _refreshBookings,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Calendar View
// ────────────────────────────────────────────────────────────────────────────
class _CalendarView extends StatelessWidget {
  final List<Booking> bookings;
  final List<User> staff;
  final List<FloorPlanTable> tables;
  final String resourceMode;
  final int timeSnappingMinutes;
  final DateTime selectedDate;
  final void Function(User?, FloorPlanTable?, TimeOfDay) onEmptySlotTap;
  final void Function(Booking) onBookingTap;
  final ScrollController? scrollController;

  const _CalendarView({
    required this.bookings,
    required this.staff,
    required this.tables,
    required this.resourceMode,
    required this.timeSnappingMinutes,
    required this.selectedDate,
    required this.onEmptySlotTap,
    required this.onBookingTap,
    this.scrollController,
  });

  double _bookingTop(Booking b) {
    final minutesFromStart =
        (b.startTime.hour - _dayStart) * 60 + b.startTime.minute;
    return (minutesFromStart / 30) * _slotHeight;
  }

  double _bookingHeight(Booking b) {
    final durationMinutes = b.endTime.difference(b.startTime).inMinutes;
    return (durationMinutes / 30) * _slotHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStaffMode = resourceMode == 'staff';
    // Staff mode: one column per staff member.
    // Table/room mode: single timeline — user picks a table inside the dialog.
    final List<String> colLabels = isStaffMode
        ? (staff.isEmpty
              ? ['Unassigned']
              : staff.map((u) => u.displayName).toList())
        : const ['Bookings'];
    final totalCols = colLabels.length;

    // "Current time" indicator — only on today, only within the visible
    // 08:00–24:00 window. `nowOffset` is its vertical position inside the
    // calendar body (same coordinate space as booking chips).
    final now = DateTime.now();
    final showNow =
        isSameDay(now, selectedDate) &&
        now.hour >= _dayStart &&
        now.hour < _dayEnd;
    final nowOffset =
        ((now.hour - _dayStart) * 60 + now.minute) / 30 * _slotHeight;
    final nowColor = theme.colorScheme.error;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _timeColWidth;
        final effectiveColWidth = isStaffMode
            ? (availableWidth / totalCols < _staffColWidth
                  ? _staffColWidth
                  : availableWidth / totalCols)
            : availableWidth;
        final effectiveGridWidth = isStaffMode
            ? totalCols * effectiveColWidth
            : availableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          controller: scrollController,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Time Labels column ────────────────────────────────────────
              SizedBox(
                width: _timeColWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: _headerRowHeight),
                        for (int i = 0; i < _totalSlots; i++)
                          SizedBox(
                            height: _slotHeight,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  top: 4,
                                ),
                                child: Text(
                                  _slotLabel(i),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Current-time pill, aligned to the indicator line.
                    if (showNow)
                      Positioned(
                        top: _headerRowHeight + nowOffset - 9,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: nowColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _fmtTime(TimeOfDay.fromDateTime(now)),
                            style: TextStyle(
                              color: theme.colorScheme.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Resource columns ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: effectiveGridWidth,
                    child: Column(
                      children: [
                        // Header row
                        SizedBox(
                          height: _headerRowHeight,
                          child: Row(
                            children: colLabels
                                .map(
                                  (label) => SizedBox(
                                    width: effectiveColWidth,
                                    child: _StaffHeader(
                                      name: label,
                                      theme: theme,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                        // Calendar body
                        SizedBox(
                          height: _totalHeight,
                          child: Stack(
                            children: [
                              // Horizontal grid lines
                              for (int i = 0; i <= _totalSlots; i++)
                                Positioned(
                                  top: i * _slotHeight,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: i % 2 == 0 ? 1.0 : 0.5,
                                    color: theme.dividerColor.withValues(
                                      alpha: i % 2 == 0 ? 0.5 : 0.25,
                                    ),
                                  ),
                                ),

                              // Vertical dividers — staff mode only
                              if (isStaffMode)
                                for (int i = 1; i < totalCols; i++)
                                  Positioned(
                                    left: i * effectiveColWidth,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 1,
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),

                              // Empty-slot tap layer
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTapDown: (details) {
                                    final rawMins =
                                        details.localPosition.dy /
                                        _slotHeight *
                                        30;
                                    final snapped =
                                        (rawMins / timeSnappingMinutes)
                                            .round() *
                                        timeSnappingMinutes;
                                    final totalMins = (_dayStart * 60 + snapped)
                                        .clamp(0, _dayEnd * 60 - 1);
                                    final time = TimeOfDay(
                                      hour: totalMins ~/ 60,
                                      minute: totalMins % 60,
                                    );
                                    // Staff mode: derive staff from tapped column.
                                    // Table mode: table is chosen inside the dialog.
                                    User? staffMember;
                                    if (isStaffMode && staff.isNotEmpty) {
                                      final col =
                                          (details.localPosition.dx /
                                                  effectiveColWidth)
                                              .floor()
                                              .clamp(0, totalCols - 1);
                                      staffMember = col < staff.length
                                          ? staff[col]
                                          : null;
                                    }
                                    onEmptySlotTap(staffMember, null, time);
                                  },
                                ),
                              ),

                              // Booking chips
                              ..._buildBookingChips(
                                isStaffMode,
                                effectiveColWidth,
                                effectiveGridWidth,
                              ),

                              // Current-time indicator line (drawn on top).
                              if (showNow)
                                Positioned(
                                  top: nowOffset - 5,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: nowColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 2,
                                            color: nowColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildBookingChips(
    bool isStaffMode,
    double colWidth,
    double totalWidth,
  ) {
    if (isStaffMode) {
      return _buildStaffChips(colWidth);
    } else {
      return _buildTableModeChips(totalWidth);
    }
  }

  String _tableLabel(Booking b) {
    if (b.tableIds.isEmpty) return '';
    return b.tableIds
        .map((id) {
          final t = tables.where((x) => x.id == id).firstOrNull;
          return t?.name ?? 'T$id';
        })
        .join(', ');
  }

  List<Widget> _buildStaffChips(double colWidth) {
    return bookings.map((booking) {
      int col = 0;
      if (booking.userId != null && staff.isNotEmpty) {
        final idx = staff.indexWhere((u) => u.id == booking.userId);
        col = idx >= 0 ? idx : 0;
      }
      return Positioned(
        top: _bookingTop(booking),
        left: col * colWidth + 2,
        width: colWidth - 4,
        height: _bookingHeight(
          booking,
        ).clamp(_slotHeight * 0.5, double.infinity),
        child: GestureDetector(
          onTap: () => onBookingTap(booking),
          child: _BookingChip(
            booking: booking,
            tableLabel: _tableLabel(booking),
          ),
        ),
      );
    }).toList();
  }

  // Overlapping bookings are placed side-by-side using lane assignment so
  // concurrent bookings (different tables booked at the same time) don't
  // visually collide.
  List<Widget> _buildTableModeChips(double totalWidth) {
    if (bookings.isEmpty) return [];

    final sorted = [...bookings]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final laneOf = <Booking, int>{};
    for (final b in sorted) {
      final occupied = sorted
          .where(
            (o) =>
                laneOf.containsKey(o) &&
                o.startTime.isBefore(b.endTime) &&
                o.endTime.isAfter(b.startTime),
          )
          .map((o) => laneOf[o]!)
          .toSet();
      int lane = 0;
      while (occupied.contains(lane)) {
        lane++;
      }
      laneOf[b] = lane;
    }

    return sorted.map((booking) {
      final myLane = laneOf[booking]!;
      final maxLane = laneOf.entries
          .where(
            (e) =>
                e.key.startTime.isBefore(booking.endTime) &&
                e.key.endTime.isAfter(booking.startTime),
          )
          .map((e) => e.value)
          .fold(0, (m, v) => v > m ? v : m);
      // Proportional width, but capped at 160 px so chips look like cubes
      // rather than full-width bars when only one booking is in a slot.
      final chipWidth = (totalWidth / (maxLane + 1)).clamp(60.0, 160.0);

      return Positioned(
        top: _bookingTop(booking),
        left: myLane * (chipWidth + 4) + 2,
        width: chipWidth,
        height: _bookingHeight(
          booking,
        ).clamp(_slotHeight * 0.5, double.infinity),
        child: GestureDetector(
          onTap: () => onBookingTap(booking),
          child: _BookingChip(
            booking: booking,
            tableLabel: _tableLabel(booking),
          ),
        ),
      );
    }).toList();
  }

  String _slotLabel(int index) {
    final totalMinutes = _dayStart * 60 + index * 30;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m != 0) return '';
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    return '$displayH $period';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Staff Header Cell
// ────────────────────────────────────────────────────────────────────────────
class _StaffHeader extends StatelessWidget {
  final String name;
  final ThemeData theme;

  const _StaffHeader({required this.name, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Booking Chip (compact card for the grid)
// ────────────────────────────────────────────────────────────────────────────
class _BookingChip extends StatelessWidget {
  final Booking booking;
  final String tableLabel;

  const _BookingChip({required this.booking, this.tableLabel = ''});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(booking.status);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          booking.reservationName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Add Booking Dialog
// ────────────────────────────────────────────────────────────────────────────
class _AddBookingDialog extends ConsumerStatefulWidget {
  final List<User> users;
  final List<FloorPlanTable> tables;
  final String resourceMode;
  final DateTime date;
  final User? prefilledStaff;
  final TimeOfDay? prefilledTime;
  final int defaultDurationMinutes;
  final VoidCallback onSaved;
  final Booking? existingBooking;

  const _AddBookingDialog({
    required this.users,
    required this.tables,
    required this.resourceMode,
    required this.date,
    this.prefilledStaff,
    this.prefilledTime,
    required this.defaultDurationMinutes,
    required this.onSaved,
    this.existingBooking,
  });

  @override
  ConsumerState<_AddBookingDialog> createState() => _AddBookingDialogState();
}

class _AddBookingDialogState extends ConsumerState<_AddBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _guestController = TextEditingController(text: '1');
  final _noteController = TextEditingController();

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  User? _selectedStaff;
  int? _selectedCustomerId;
  bool _customerDefaultSet = false;
  final Set<int> _selectedTableIds = {};
  bool _saving = false;

  static Customer? _findDefaultCustomer(List<Customer> list) {
    if (list.isEmpty) return null;
    return list
            .where(
              (c) => c.code == 'C000' || c.name.toLowerCase().contains('walk'),
            )
            .firstOrNull ??
        list.first;
  }

  /// Rounds the current wall-clock time UP to the next multiple of [snapMins].
  static TimeOfDay _snapToNextSlot(int snapMins) {
    final now = DateTime.now();
    final total = now.hour * 60 + now.minute;
    final snapped = ((total / snapMins).ceil()) * snapMins;
    return TimeOfDay(hour: (snapped ~/ 60).clamp(0, 23), minute: snapped % 60);
  }

  @override
  void initState() {
    super.initState();
    final b = widget.existingBooking;
    if (b != null) {
      // Edit mode — pre-fill everything from the existing booking
      _nameController.text = b.reservationName;
      _guestController.text = b.guestCount.toString();
      _noteController.text = b.note ?? '';
      _startTime = TimeOfDay.fromDateTime(b.startTime);
      _endTime = TimeOfDay.fromDateTime(b.endTime);
      _selectedStaff = widget.users.where((u) => u.id == b.userId).firstOrNull;
      _selectedTableIds.addAll(b.tableIds);
      _selectedCustomerId = b.customerId;
    } else {
      // New booking mode
      _startTime = widget.prefilledTime ?? _snapToNextSlot(15);
      final endTotal =
          _startTime.hour * 60 +
          _startTime.minute +
          widget.defaultDurationMinutes;
      _endTime = TimeOfDay(
        hour: (endTotal ~/ 60).clamp(0, 23),
        minute: endTotal % 60,
      );
      _selectedStaff =
          widget.prefilledStaff ??
          (widget.users.isNotEmpty ? widget.users.first : null);
      // Eager default: set Walk-in customer if the provider is already cached.
      final earlyCustomers = ref.read(selectableCustomersProvider).value ?? [];
      final def = _findDefaultCustomer(earlyCustomers);
      if (def != null) {
        _selectedCustomerId = def.id;
        _customerDefaultSet = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _guestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime _toDateTime(TimeOfDay t) => DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
    t.hour,
    t.minute,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.resourceMode != 'staff' && _selectedTableIds.isEmpty) {
      showAppSnackbar(
        context,
        ref,
        'Please select at least one table.',
        isError: true,
      );
      return;
    }
    final allowPast = ref
        .read(appSettingsProvider.notifier)
        .bookingSettings
        .allowPastBookings;
    if (!allowPast && _toDateTime(_startTime).isBefore(DateTime.now())) {
      showAppSnackbar(
        context,
        ref,
        'Cannot create a booking in the past.',
        isError: true,
      );
      return;
    }
    if (!_toDateTime(_endTime).isAfter(_toDateTime(_startTime))) {
      showAppSnackbar(
        context,
        ref,
        'End time must be after start time.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);

    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    try {
      // Offline-first: write to local Drift (instant UI via the stream) and
      // queue the change; SyncManager.pushPendingBookings sends it on reconnect.
      final db = ref.read(appDatabaseProvider);
      final start = _toDateTime(_startTime);
      final end = _toDateTime(_endTime);
      final name = _nameController.text.trim();
      final guests = int.tryParse(_guestController.text) ?? 1;
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();
      final tableIds = _selectedTableIds.toList();

      if (widget.existingBooking != null) {
        // Edit mode — update in place (preserve document/order links + status).
        await db.upsertBookingLocal(
          id: widget.existingBooking!.id,
          companyId: companyId,
          customerId: _selectedCustomerId,
          userId: _selectedStaff?.id,
          reservationName: name,
          tableIds: tableIds,
          documentId: widget.existingBooking!.documentId,
          posOrderId: widget.existingBooking!.posOrderId,
          startTime: start,
          endTime: end,
          guestCount: guests,
          status: widget.existingBooking!.status,
          note: note,
        );
        ref.read(syncStateProvider.notifier).sync().catchError((_) {});
        widget.onSaved();
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        // Create mode — local create with a temp id (pending_create).
        final tempId = await db.upsertBookingLocal(
          companyId: companyId,
          customerId: _selectedCustomerId,
          userId: _selectedStaff?.id,
          reservationName: name,
          tableIds: tableIds,
          startTime: start,
          endTime: end,
          guestCount: guests,
          status: 1,
          note: note,
        );
        ref.read(syncStateProvider.notifier).sync().catchError((_) {});
        widget.onSaved();
        if (!mounted) return;

        final created = Booking(
          id: tempId,
          customerId: _selectedCustomerId,
          userId: _selectedStaff?.id,
          reservationName: name,
          tableIds: tableIds,
          startTime: start,
          endTime: end,
          guestCount: guests,
          status: 1,
          note: note,
          syncStatus: 'pending_create',
        );

        final action = await showDialog<_PostSaveAction>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Booking Saved!'),
            content: Text(
              '${created.reservationName} has been scheduled for '
              '${_fmtDateTime(created.startTime)}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, _PostSaveAction.stay),
                child: const Text('Stay on Calendar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text(
                  'Open Order Now',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () => Navigator.pop(ctx, _PostSaveAction.open),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (action == _PostSaveAction.open) {
          final user = ref.read(currentUserProvider);
          if (user != null) {
            await ref
                .read(cartProvider.notifier)
                .startBookingOrder(
                  ApiClient(),
                  companyId,
                  user.id,
                  created.id,
                  created.reservationName,
                  staffUserId: created.userId,
                  floorPlanTableId: created.tableIds.firstOrNull,
                  customerId: created.customerId,
                );
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MenuScreen()),
              (route) => false,
            );
          }
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onStartTimeChanged(TimeOfDay t) {
    setState(() {
      _startTime = t;
      final endTotal = t.hour * 60 + t.minute + widget.defaultDurationMinutes;
      // Cap at 23:59 to avoid midnight overflow making end ≤ start.
      final clampedTotal = endTotal.clamp(0, 23 * 60 + 59);
      _endTime = TimeOfDay(hour: clampedTotal ~/ 60, minute: clampedTotal % 60);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTableMode = widget.resourceMode != 'staff';
    final existingBookings = ref.watch(allBookingsProvider).value ?? [];
    final customers = ref.watch(selectableCustomersProvider).value ?? [];

    // Lazy default: fires once when the provider resolves after initState.
    if (!_customerDefaultSet && customers.isNotEmpty) {
      _customerDefaultSet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedCustomerId != null) return;
        final def = _findDefaultCustomer(customers);
        if (def != null) setState(() => _selectedCustomerId = def.id);
      });
    }

    return AlertDialog(
      title: Text(
        widget.existingBooking != null ? 'Edit Booking' : 'New Booking',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  key: ValueKey(_selectedCustomerId),
                  initialValue: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    prefixIcon: Icon(Icons.account_circle),
                  ),
                  items: customers
                      .where((c) => c.isCustomer)
                      .map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    setState(() => _selectedCustomerId = id);
                    if (id != null) {
                      final c = customers.where((c) => c.id == id).firstOrNull;
                      if (c != null) _nameController.text = c.name;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Guest Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TimePicker(
                        label: 'Start Time',
                        time: _startTime,
                        onChanged: _onStartTimeChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimePicker(
                        label: 'End Time',
                        time: _endTime,
                        onChanged: (t) => setState(() => _endTime = t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _guestController,
                        decoration: const InputDecoration(
                          labelText: 'Guests',
                          prefixIcon: Icon(Icons.people),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<User?>(
                        initialValue: _selectedStaff,
                        decoration: const InputDecoration(
                          labelText: 'Staff',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        items: [
                          const DropdownMenuItem<User?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ...widget.users.map(
                            (u) => DropdownMenuItem<User?>(
                              value: u,
                              child: Text(u.displayName),
                            ),
                          ),
                        ],
                        onChanged: (u) => setState(() => _selectedStaff = u),
                      ),
                    ),
                  ],
                ),
                // Table availability picker — shown in table/room mode
                if (isTableMode) ...[
                  const SizedBox(height: 16),
                  _TableAvailabilityPicker(
                    tables: widget.tables,
                    selectedIds: _selectedTableIds,
                    existingBookings: existingBookings,
                    excludeBookingId: widget.existingBooking?.id,
                    startTime: _toDateTime(_startTime),
                    endTime: _toDateTime(_endTime),
                    onToggled: (t) => setState(() {
                      if (_selectedTableIds.contains(t.id)) {
                        _selectedTableIds.remove(t.id);
                      } else {
                        _selectedTableIds.add(t.id);
                      }
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.successColor,
            foregroundColor: context.onStatusColor,
          ),
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.onStatusColor,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Table Availability Picker
// ────────────────────────────────────────────────────────────────────────────
class _TableAvailabilityPicker extends StatelessWidget {
  final List<FloorPlanTable> tables;
  final Set<int> selectedIds;
  final List<Booking> existingBookings;
  final int? excludeBookingId;
  final DateTime startTime;
  final DateTime endTime;
  final ValueChanged<FloorPlanTable> onToggled;

  const _TableAvailabilityPicker({
    required this.tables,
    required this.selectedIds,
    required this.existingBookings,
    this.excludeBookingId,
    required this.startTime,
    required this.endTime,
    required this.onToggled,
  });

  bool _available(FloorPlanTable t) => !existingBookings.any(
    (b) =>
        b.status != 4 &&
        b.status != 5 &&
        b.id != excludeBookingId &&
        b.tableIds.contains(t.id) &&
        b.startTime.isBefore(endTime) &&
        b.endTime.isAfter(startTime),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = tables.where(_available).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.table_restaurant,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text('Select Tables *', style: theme.textTheme.labelLarge),
            const Spacer(),
            if (selectedIds.isNotEmpty)
              Text(
                '${selectedIds.length} selected',
                style: TextStyle(
                  fontSize: 12,
                  color: context.successColor,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                '${available.length} available',
                style: TextStyle(
                  fontSize: 12,
                  color: context.successColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (available.isEmpty)
          Text(
            tables.isEmpty
                ? 'No tables configured.'
                : 'No tables available for this time slot.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: available
                .map(
                  (t) => _TableChip(
                    table: t,
                    selected: selectedIds.contains(t.id),
                    onTap: () => onToggled(t),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _TableChip extends StatelessWidget {
  final FloorPlanTable table;
  final bool selected;
  final VoidCallback? onTap;

  const _TableChip({
    required this.table,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg, border, fg;
    if (selected) {
      bg = context.successColor.withValues(alpha: 0.15);
      border = context.successColor;
      fg = context.successColor;
    } else {
      bg = theme.colorScheme.surface;
      border = theme.colorScheme.outline;
      fg = theme.colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.check_circle_outline,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              table.name,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Booking Detail / Status Update Dialog
// ────────────────────────────────────────────────────────────────────────────
class _BookingDetailDialog extends ConsumerStatefulWidget {
  final Booking booking;
  final List<User> staff;
  final List<FloorPlanTable> tables;
  final String resourceMode;
  final VoidCallback onUpdated;

  const _BookingDetailDialog({
    required this.booking,
    required this.staff,
    required this.tables,
    required this.resourceMode,
    required this.onUpdated,
  });

  @override
  ConsumerState<_BookingDetailDialog> createState() =>
      _BookingDetailDialogState();
}

class _BookingDetailDialogState extends ConsumerState<_BookingDetailDialog> {
  bool _saving = false;

  String _staffName(int? userId) {
    if (userId == null) return 'Unassigned';
    final u = widget.staff.where((s) => s.id == userId).firstOrNull;
    return u?.displayName ?? 'Staff #$userId';
  }

  Future<void> _updateStatus(int newStatus) async {
    setState(() => _saving = true);
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    try {
      // Offline-first: flip the status locally (instant) + queue the push.
      await ref
          .read(appDatabaseProvider)
          .setBookingStatusLocal(widget.booking.id, newStatus);
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startService() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    final user = ref.read(currentUserProvider);
    if (companyId == null || user == null) return;

    // When multiple tables are assigned, ask which one carries the order.
    int? chosenTableId = widget.booking.tableIds.firstOrNull;
    if (widget.booking.tableIds.length > 1) {
      chosenTableId = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Which table should this order be placed on?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.booking.tableIds.map((id) {
              final t = widget.tables.where((x) => x.id == id).firstOrNull;
              return ListTile(
                leading: const Icon(Icons.table_restaurant),
                title: Text(t?.name ?? 'Table #$id'),
                onTap: () => Navigator.pop(ctx, id),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (chosenTableId == null || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      // Seeds the cart with this booking's context (carries bookingId so the
      // backend links the order + flips the booking to In Service when the
      // order is saved/checked out). This call is local-only — no network.
      await ref
          .read(cartProvider.notifier)
          .startBookingOrder(
            ApiClient(),
            companyId,
            user.id,
            widget.booking.id,
            widget.booking.reservationName,
            staffUserId: widget.booking.userId,
            floorPlanTableId: chosenTableId,
            customerId: widget.booking.customerId,
          );

      // Mark every assigned table as occupied on the floor plan
      final client = ApiClient();
      for (final tableId in widget.booking.tableIds) {
        try {
          await client.occupyFloorPlanTable(companyId, tableId);
        } catch (_) {}
      }

      widget.onUpdated();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MenuScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openOrder() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    final warehouseId = ref.read(selectedWarehouseProvider)?.id ?? 1;
    if (companyId == null) return;

    setState(() => _saving = true);
    try {
      final loaded = await ref
          .read(cartProvider.notifier)
          .loadOrderById(
            ApiClient(),
            companyId,
            widget.booking.posOrderId!,
            warehouseId,
          );
      if (!mounted) return;
      if (!loaded) {
        showAppSnackbar(
          context,
          ref,
          'Order not found. It may have been completed or voided.',
          isError: true,
        );
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MenuScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDocument() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null || widget.booking.documentId == null) return;
    setState(() => _saving = true);
    try {
      final dio = createDio();
      final response = await dio.get(
        '/Document/GetById',
        queryParameters: {
          'id': widget.booking.documentId,
          'companyId': companyId,
        },
      );
      if (!mounted) return;
      final doc = Document.fromJson(response.data as Map<String, dynamic>);
      await showDocumentEditor(context, ref, existingDocument: doc);
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Booking'),
        content: Text(
          'Delete booking for "${widget.booking.reservationName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              foregroundColor: ctx.onStatusColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _saving = true);
    final companyId = ref.read(selectedCompanyProvider)?.id;

    if (companyId == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      // Offline-first: tombstone locally (drops off the calendar at once) and
      // queue the server delete for the next sync.
      await ref
          .read(appDatabaseProvider)
          .deleteBookingLocal(widget.booking.id);
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Touch-sized status pill ────────────────────────────────────────────────
  // The active status keeps a saturated fill + check + white ring; the others
  // are tappable to switch. Tall (54px) so it's an easy finger target.
  Widget _statusBtn(int currentStatus, int s) {
    final isCurrent = currentStatus == s;
    final color = _statusColor(s);
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: (isCurrent || _saving) ? null : () => _updateStatus(s),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          // Current stays full colour (it's disabled); others only fade while a
          // save is in flight.
          disabledBackgroundColor: color.withValues(
            alpha: isCurrent ? 1.0 : 0.35,
          ),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isCurrent
                ? const BorderSide(color: Colors.white, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCurrent) ...[
              const Icon(Icons.check_circle, size: 17, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                _statusLabel(s),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onEdit() {
    final bs = ref.read(appSettingsProvider.notifier).bookingSettings;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => _AddBookingDialog(
        users: widget.staff,
        tables: widget.tables,
        resourceMode: widget.resourceMode,
        date: widget.booking.startTime,
        defaultDurationMinutes: bs.defaultDurationMinutes,
        existingBooking: widget.booking,
        onSaved: widget.onUpdated,
      ),
    );
  }

  /// Full-width primary call-to-action (height 56). Returns null when the
  /// booking has no primary action (e.g. a No-Show, or a completed booking with
  /// no document).
  Widget? _primaryCta() {
    final b = widget.booking;
    if (b.status == 4) {
      if (b.documentId == null) return null;
      return _bigButton(
        icon: Icons.receipt,
        label: 'Open Document',
        color: Colors.teal,
        onTap: _openDocument,
      );
    }
    if (b.status == 5) return null; // No Show — nothing to start
    if (b.posOrderId != null) {
      return _bigButton(
        icon: Icons.receipt_long,
        label: 'Open Order',
        color: Colors.indigo,
        onTap: _openOrder,
      );
    }
    return _bigButton(
      icon: Icons.play_arrow,
      label: 'Start Service',
      color: Colors.teal,
      onTap: _startService,
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _saving ? null : onTap,
      ),
    );
  }

  /// Large outlined secondary button (height 50) for the footer row.
  Widget _secondaryButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: c),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: c,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = widget.booking;
    final statusColor = _statusColor(b.status);
    final canModify = b.status != 4;
    final primary = _primaryCta();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
      title: Row(
        children: [
          Expanded(
            child: Text(
              b.reservationName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: ShapeDecoration(
              color: statusColor.withValues(alpha: 0.16),
              shape: const StadiumBorder(),
            ),
            child: Text(
              _statusLabel(b.status),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                icon: Icons.access_time,
                text:
                    '${_fmtDateTime(b.startTime)} – ${_fmtDateTime(b.endTime)}',
              ),
              _DetailRow(icon: Icons.people, text: '${b.guestCount} guest(s)'),
              _DetailRow(icon: Icons.badge, text: _staffName(b.userId)),
              if (b.note != null && b.note!.isNotEmpty)
                _DetailRow(icon: Icons.notes, text: b.note!),
              if (b.tableIds.isNotEmpty)
                _DetailRow(
                  icon: Icons.table_restaurant,
                  text: b.tableIds
                      .map((id) {
                        final t = widget.tables
                            .where((x) => x.id == id)
                            .firstOrNull;
                        return t?.name ?? 'Table #$id';
                      })
                      .join(', '),
                ),
              if (b.status == 4) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.successColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.successColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: context.successColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This booking is completed and cannot be modified.',
                          style: TextStyle(
                              color: context.successColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                Text(
                  'UPDATE STATUS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [1, 2, 3]
                      .expand(
                        (s) => [
                          if (s > 1) const SizedBox(width: 10),
                          Expanded(child: _statusBtn(b.status, s)),
                        ],
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [4, 5]
                      .expand(
                        (s) => [
                          if (s > 4) const SizedBox(width: 10),
                          Expanded(child: _statusBtn(b.status, s)),
                        ],
                      )
                      .toList(),
                ),
              ],

              const SizedBox(height: 22),
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),

              // ── Primary call-to-action (full width) ──────────────────────
              if (primary != null) ...[primary, const SizedBox(height: 12)],

              // ── Secondary actions row (big touch targets) ────────────────
              Row(
                children: [
                  if (canModify) ...[
                    Expanded(
                      child: _secondaryButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: context.dangerColor,
                        onTap: _saving ? null : _delete,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _secondaryButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: _saving ? null : _onEdit,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _secondaryButton(
                      icon: Icons.close,
                      label: 'Close',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _AlertRow({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Time Picker helper widget
// ────────────────────────────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time, size: 18),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        child: Text(_fmtTime(time), style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
