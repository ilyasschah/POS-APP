import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/bookings/booking_model.dart';
import 'package:pos_app/bookings/bookings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/sync/sync_provider.dart';

class BookingHistoryScreen extends ConsumerStatefulWidget {
  /// Opens the global navigation drawer (supplied by MainLayout). When null —
  /// e.g. the screen is pushed as a standalone route — the leading hamburger is
  /// hidden, matching the other POS tab screens.
  final VoidCallback? onMenuPressed;

  const BookingHistoryScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<BookingHistoryScreen> createState() =>
      _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Pulls bookings from the server into the local Drift cache. The
  /// Drift-backed [allBookingsProvider] stream re-emits when the rows land.
  /// Offline, this no-ops and the existing cache stays on screen.
  void _refresh() {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    ref.read(syncManagerProvider).pullBookings(companyId).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final asyncBookings = ref.watch(allBookingsProvider);

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Unified flat top bar (replaces the legacy Material AppBar): title
          // left-middle, refresh pinned right. The TabBar drops just beneath it.
          PosTopBar(
            onMenuPressed: widget.onMenuPressed,
            title: Text(
              AppLocalizations.of(context).bookingHistory,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: AppLocalizations.of(context).refresh,
                onPressed: _refresh,
              ),
            ],
          ),
          // Flat tab strip: solid surface fill, crisp bottom divider, no shadow.
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: context.navDivider)),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                    icon: const Icon(Icons.upcoming),
                    text: AppLocalizations.of(context).upcoming),
                Tab(
                    icon: const Icon(Icons.history),
                    text: AppLocalizations.of(context).historyTab),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchByName,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: asyncBookings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(AppLocalizations.of(context).errorLoadingBookings(e.toString()))),
              data: (bookings) {
                final filtered = _search.isEmpty
                    ? bookings
                    : bookings
                          .where(
                            (b) => b.reservationName.toLowerCase().contains(
                              _search,
                            ),
                          )
                          .toList();

                final upcoming =
                    filtered
                        .where(
                          (b) =>
                              b.status == 1 || b.status == 2 || b.status == 3,
                        )
                        .toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime));

                final history =
                    filtered
                        .where((b) => b.status == 4 || b.status == 5)
                        .toList()
                      ..sort((a, b) => b.startTime.compareTo(a.startTime));

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _BookingList(
                      bookings: upcoming,
                      emptyMessage:
                          AppLocalizations.of(context).noUpcomingBookings,
                      emptyIcon: Icons.event_available,
                    ),
                    _BookingList(
                      bookings: history,
                      emptyMessage:
                          AppLocalizations.of(context).noCompletedBookings,
                      emptyIcon: Icons.history_toggle_off,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyMessage;
  final IconData emptyIcon;

  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptyIcon,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _BookingCard(booking: bookings[i]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;

  const _BookingCard({required this.booking});

  /// Booking status id → label. The ids are the server's, so only the label
  /// is localized — same id+lookup split as the security keys in users_screen.
  static String _statusLabelFor(BuildContext context, int status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 1:
        return l10n.bookingPending;
      case 2:
        return l10n.bookingArrived;
      case 3:
        return l10n.bookingInService;
      case 4:
        return l10n.bookingCompleted;
      case 5:
        return l10n.bookingNoShow;
      default:
        return l10n.unknownLabel;
    }
  }

  static const _statusColor = {
    1: Color(0xFFFFA726), // amber
    2: Color(0xFF42A5F5), // blue
    3: Color(0xFFEF6C00), // deep orange
    4: Color(0xFF66BB6A), // green
    5: Color(0xFF9E9E9E), // grey
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateFmt = DateFormat('EEE, d MMM yyyy');
    final timeFmt = DateFormat('HH:mm');

    final statusColor = _statusColor[booking.status] ?? cs.outline;
    final statusLabel = _statusLabelFor(context, booking.status);

    final duration = booking.endTime.difference(booking.startTime);
    final durationLabel = duration.inMinutes >= 60
        ? '${duration.inHours}h ${duration.inMinutes % 60}m'
        : '${duration.inMinutes}m';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coloured status bar
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.reservationName,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(label: statusLabel, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFmt.format(booking.startTime),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${timeFmt.format(booking.startTime)} – ${timeFmt.format(booking.endTime)} ($durationLabel)',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)
                            .guestsCount(booking.guestCount),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      if (booking.tableIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.table_restaurant,
                          size: 13,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)
                              .tablesCount(booking.tableIds.length),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      if (booking.posOrderId != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.receipt,
                          size: 13,
                          color: cs.primary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)
                              .orderNumbered('${booking.posOrderId}'),
                          style: tt.bodySmall?.copyWith(color: cs.primary),
                        ),
                      ],
                    ],
                  ),
                  if (booking.note != null && booking.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes,
                          size: 13,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.note!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
