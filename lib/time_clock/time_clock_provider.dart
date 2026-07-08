import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// The currently logged-in user's active (open) clock entry.
/// Emits null when they are not clocked in.
final activeClockEntryProvider = StreamProvider<TimeClockEntriesTableData?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value(null);

  return (db.select(db.timeClockEntriesTable)
        ..where((t) => t.userId.equals(userId))
        ..where((t) => t.clockOutTime.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.clockInTime)])
        ..limit(1))
      .watchSingleOrNull();
});

/// An open clock entry for any user — used by the kiosk Time Clock screen
/// to check if a specific userId (identified by PIN) is currently clocked in.
final activeClockEntryForUserProvider =
    StreamProvider.autoDispose.family<TimeClockEntriesTableData?, int>(
  (ref, userId) {
    final db = ref.watch(appDatabaseProvider);
    return (db.select(db.timeClockEntriesTable)
          ..where((t) => t.userId.equals(userId))
          ..where((t) => t.clockOutTime.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.clockInTime)])
          ..limit(1))
        .watchSingleOrNull();
  },
);

final timeClockNotifierProvider =
    NotifierProvider<TimeClockNotifier, void>(() => TimeClockNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class TimeClockNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(appDatabaseProvider);

  int? get _companyId => ref.read(selectedCompanyProvider)?.id;

  /// Clocks in the user identified by [userId].
  /// Returns an error string if the user is already clocked in, null on success.
  Future<String?> clockIn(int userId) async {
    final companyId = _companyId;
    if (companyId == null) return 'No company selected.';

    final existing = await _db.getActiveClockEntry(userId);
    if (existing != null) return 'Already clocked in.';

    await _db.insertClockIn(
      TimeClockEntriesTableCompanion(
        localId: Value(const Uuid().v4()),
        companyId: Value(companyId),
        userId: Value(userId),
        clockInTime: Value(DateTime.now().toUtc()),
        syncStatus: const Value('pending'),
      ),
    );
    return null;
  }

  /// Clocks out the user identified by [userId].
  /// Returns an error string if they are not clocked in, null on success.
  Future<String?> clockOut(int userId) async {
    if (_companyId == null) return 'No company selected.';

    final entry = await _db.getActiveClockEntry(userId);
    if (entry == null) return 'Not currently clocked in.';

    await _db.clockOut(entry.localId, DateTime.now().toUtc());
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN → USER LOOKUP  (used by the kiosk screen — no POS login required)
// ─────────────────────────────────────────────────────────────────────────────

/// Hashes a raw 4-digit PIN string to sha256/base64, matching the server's
/// format, then searches the local users table for a matching pinHash row.
/// Returns null if no user has that PIN registered on this device.
Future<UsersTableData?> findUserByPin(AppDatabase db, int companyId, String pin) async {
  final bytes = utf8.encode(pin);
  final digest = sha256.convert(bytes);
  final hashed = base64Encode(digest.bytes);

  final rows = await (db.select(db.usersTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.isEnabled.equals(true)))
      .get();

  try {
    return rows.firstWhere((u) => u.pinHash == hashed);
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOURS CALCULATION UTILITY
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a human-readable duration string: "3h 25m" or "45m".
/// If [clockOutTime] is null, calculates from [clockInTime] to now.
String formatWorkedDuration(DateTime clockInTime, [DateTime? clockOutTime]) {
  final end = (clockOutTime ?? DateTime.now().toUtc()).toUtc();
  final duration = end.difference(clockInTime.toUtc());
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Returns the total minutes worked between two times.
int workedMinutes(DateTime clockInTime, [DateTime? clockOutTime]) {
  final end = (clockOutTime ?? DateTime.now().toUtc()).toUtc();
  return end.difference(clockInTime.toUtc()).inMinutes;
}

// ─────────────────────────────────────────────────────────────────────────────
// HOURS REPORT DATA
// ─────────────────────────────────────────────────────────────────────────────

/// One row in the hours report table.
class HoursReportRow {
  final String employeeName;
  final int totalMinutes;
  const HoursReportRow({required this.employeeName, required this.totalMinutes});
}

/// Family key for [hoursReportProvider]. Uses plain DateTimes so the provider
/// file doesn't import the Flutter material library.
typedef HoursQueryParams = ({
  DateTime rangeStart,
  DateTime rangeEnd,
  int? userId,
  int companyId,
});

/// Aggregates total worked minutes per employee within the given date range.
/// If [userId] is null, all employees are returned (with > 0 minutes).
///
/// Pure offline-first reader: queries the local indexed `shiftsTable` (the
/// unified clock-in/out source) directly — fully insulated from the network.
/// Each shift contributes `(closedAt ?? now) - openedAt`, clamped into the
/// UTC [rangeStart] .. [rangeEnd] window.
final hoursReportProvider =
    FutureProvider.autoDispose.family<List<HoursReportRow>, HoursQueryParams>(
  (ref, params) async {
    if (params.companyId == 0) return const [];
    final db = ref.watch(appDatabaseProvider);

    final usersQuery = db.select(db.usersTable)
      ..where((t) => t.companyId.equals(params.companyId));
    if (params.userId != null) {
      usersQuery.where((t) => t.id.equals(params.userId!));
    }
    final users = await usersQuery.get();

    final shifts = await (db.select(db.shiftsTable)
          ..where((t) => t.companyId.equals(params.companyId)))
        .get();

    // Build per-user minute totals, clamped to the selected date range.
    final Map<int, int> minutesByUser = {};
    for (final s in shifts) {
      if (params.userId != null && s.userId != params.userId) continue;
      final openedAt = s.openedAt.toUtc();
      if (openedAt.isAfter(params.rangeEnd) ||
          openedAt.isBefore(params.rangeStart)) {
        continue;
      }
      final closedAt = (s.closedAt ?? DateTime.now()).toUtc();
      final mins = closedAt.difference(openedAt).inMinutes.clamp(0, 24 * 60);
      minutesByUser[s.userId] = (minutesByUser[s.userId] ?? 0) + mins;
    }

    final results = <HoursReportRow>[];
    for (final u in users) {
      final mins = minutesByUser[u.id] ?? 0;
      if (mins == 0) continue;
      final name = [u.firstName, u.lastName]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' ')
          .trim();
      results.add(HoursReportRow(
        employeeName: name.isEmpty ? (u.username ?? 'User #${u.id}') : name,
        totalMinutes: mins,
      ));
    }
    results.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return results;
  },
);

/// One clock-in/out session row in the detailed Hours Report grid.
class ShiftSessionRow {
  final String employeeName;
  final DateTime clockIn; // local time
  final DateTime? clockOut; // local time; null while the shift is still open
  const ShiftSessionRow({
    required this.employeeName,
    required this.clockIn,
    required this.clockOut,
  });

  bool get isOpen => clockOut == null;

  /// Minutes worked; for an open session, measured up to "now".
  int get totalMinutes {
    final end = clockOut ?? DateTime.now();
    final m = end.difference(clockIn).inMinutes;
    return m < 0 ? 0 : m;
  }
}

String _userDisplayName(UsersTableData u) {
  final name = [u.firstName, u.lastName]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ')
      .trim();
  return name.isEmpty ? (u.username ?? 'User #${u.id}') : name;
}

/// Detailed, **reactive** per-session reader: one row per shift (clock-in
/// window) within the UTC range, newest first. Pure offline-first — streams
/// the local `shiftsTable` so manually-added time cards appear instantly.
/// Open shifts keep `clockOut` null so the UI can render "Open".
final shiftSessionsProvider =
    StreamProvider.autoDispose.family<List<ShiftSessionRow>, HoursQueryParams>(
  (ref, params) {
    if (params.companyId == 0) return Stream.value(const []);
    final db = ref.watch(appDatabaseProvider);

    final query = db.select(db.shiftsTable)
      ..where((t) => t.companyId.equals(params.companyId))
      ..orderBy([(t) => OrderingTerm.desc(t.openedAt)]);

    return query.watch().asyncMap((shifts) async {
      final users = await (db.select(db.usersTable)
            ..where((t) => t.companyId.equals(params.companyId)))
          .get();
      final namesById = {for (final u in users) u.id: _userDisplayName(u)};

      final results = <ShiftSessionRow>[];
      for (final s in shifts) {
        if (params.userId != null && s.userId != params.userId) continue;
        final openedAtUtc = s.openedAt.toUtc();
        if (openedAtUtc.isAfter(params.rangeEnd) ||
            openedAtUtc.isBefore(params.rangeStart)) {
          continue;
        }
        results.add(ShiftSessionRow(
          employeeName: namesById[s.userId] ?? 'User #${s.userId}',
          clockIn: s.openedAt.toLocal(),
          clockOut: s.closedAt?.toLocal(),
        ));
      }
      return results;
    });
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR BADGE SUPPORT
// ─────────────────────────────────────────────────────────────────────────────

/// Streams the current user's total minutes worked today (UTC day boundary),
/// aggregated from the unified `shiftsTable`. Emits 0 when no shifts exist or
/// the user is logged out.
final todayTotalMinutesProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null || companyId == null) return Stream.value(0);

  final today = DateTime.now();
  final todayStartUtc =
      DateTime(today.year, today.month, today.day).toUtc();

  return (db.select(db.shiftsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.userId.equals(userId)))
      .watch()
      .map((shifts) {
    int total = 0;
    for (final s in shifts) {
      final openedAt = s.openedAt.toUtc();
      if (openedAt.isBefore(todayStartUtc)) continue;
      final closedAt = (s.closedAt ?? DateTime.now()).toUtc();
      total += closedAt.difference(openedAt).inMinutes.clamp(0, 24 * 60);
    }
    return total;
  });
});

/// Formats a minute duration for the sidebar badge:
/// - Under 60 min  → "-45m"
/// - 60 min or more → "HH:MM"
String formatSidebarDuration(int totalMinutes) {
  if (totalMinutes < 60) return '-${totalMinutes}m';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
