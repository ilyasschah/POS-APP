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

/// Stream of the **current user's** active (status=0) shift for the selected
/// company — this is the single source of truth for "My Shift" and the live
/// sidebar clocked-in counter. Emits null when the user has no open shift.
final activeShiftProvider = StreamProvider<ShiftsTableData?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  final userId = ref.watch(currentUserProvider)?.id;
  if (companyId == null || userId == null) return Stream.value(null);

  return (db.select(db.shiftsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.userId.equals(userId))
        ..where((t) => t.status.equals(0))
        ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
        ..limit(1))
      .watchSingleOrNull();
});

/// Ordered history of all shifts for the selected company (newest first).
final shiftHistoryProvider = StreamProvider<List<ShiftsTableData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  return (db.select(db.shiftsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..orderBy([(t) => OrderingTerm.desc(t.openedAt)]))
      .watch();
});

final shiftNotifierProvider =
    NotifierProvider<ShiftNotifier, void>(() => ShiftNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class ShiftNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(appDatabaseProvider);

  /// Opens a new shift (== a clock-in session) with the given starting cash.
  ///
  /// [userId] defaults to the logged-in POS user, so the Shift dashboard keeps
  /// calling `startShift(0)` unchanged. The pre-login Time Clock kiosk passes an
  /// explicit [userId] (the PIN-identified employee) so attendance is recorded
  /// per employee even when no POS user is signed in.
  ///
  /// [isDrawerShift] marks the station's master cash-drawer shift. The Shift
  /// dashboard opens a drawer shift (true); the kiosk opens bare attendance
  /// sessions (false), so many servers can clock in on one station at once
  /// without colliding with the single drawer shift.
  Future<void> startShift(
    double startingCash, {
    int? userId,
    bool isDrawerShift = false,
  }) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    final uid = userId ?? ref.read(currentUserProvider)?.id;
    if (companyId == null || uid == null) return;

    final now = DateTime.now().toUtc();
    final localId = const Uuid().v4();

    await _db.insertOfflineShift(
      ShiftsTableCompanion(
        localId: Value(localId),
        companyId: Value(companyId),
        userId: Value(uid),
        startingCash: Value(startingCash),
        status: const Value(0),
        openedAt: Value(now),
        lastModified: Value(now),
        isDrawerShift: Value(isDrawerShift),
        syncStatus: const Value('pending'),
      ),
    );

    // Record the starting cash as a cash-in movement so it appears in the
    // cash movement history and counts toward the drawer balance.
    if (startingCash > 0) {
      await _db.insertOfflineCashMovement(
        StartingCashTableCompanion(
          localId: Value(const Uuid().v4()),
          companyId: Value(companyId),
          userId: Value(uid),
          amount: Value(startingCash),
          type: const Value('in'),
          note: const Value('Shift opening float'),
          createdAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
    }
  }

  /// The given user's currently-open **attendance** shift for the selected
  /// company, or null. Scoped to `isDrawerShift == false` so the kiosk clock-in/
  /// out path can never read or close the station's master drawer shift.
  Future<ShiftsTableData?> _openAttendanceShiftForUser(
      int companyId, int userId) {
    return (_db.select(_db.shiftsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.userId.equals(userId))
          ..where((t) => t.status.equals(0))
          ..where((t) => t.isDrawerShift.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Whether [userId] is currently clocked in (has an open attendance shift).
  Future<bool> hasOpenShift(int userId) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return false;
    return (await _openAttendanceShiftForUser(companyId, userId)) != null;
  }

  /// Closes [userId]'s open attendance shift (kiosk clock-out). Returns false if
  /// they had none; true once the specific row is flipped to closed. Never
  /// touches the drawer shift.
  Future<bool> closeShiftForUser(int userId) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return false;
    final shift = await _openAttendanceShiftForUser(companyId, userId);
    if (shift == null) return false;
    await closeShift(shift);
    return true;
  }

  /// Admin override: records a completed (status=1) shift session for [userId]
  /// spanning [clockInUtc] → [clockOutUtc] — for employees who forgot to clock
  /// in/out. Offline-first (`syncStatus: 'pending'`) and written inside a
  /// transaction so the row lands atomically. Because the session is already
  /// closed it never creates an open row, so it can't violate the
  /// "one open shift at a time" rule.
  Future<void> addManualTimeCard({
    required int userId,
    required DateTime clockInUtc,
    required DateTime clockOutUtc,
  }) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _db.insertOfflineShift(
        ShiftsTableCompanion(
          localId: Value(const Uuid().v4()),
          companyId: Value(companyId),
          userId: Value(userId),
          startingCash: const Value(0),
          status: const Value(1), // completed
          openedAt: Value(clockInUtc.toUtc()),
          closedAt: Value(clockOutUtc.toUtc()),
          lastModified: Value(now),
          isDrawerShift: const Value(false), // attendance, not the drawer
          syncStatus: const Value('pending'),
        ),
      );
    });
  }

  /// Closes the current open shift.
  ///
  /// A pure, instant time-stamping operation: it flips the active shift row to
  /// status=1 and writes [closedAt]. No cash-movement / payment aggregation and
  /// no Z-report snapshot are produced here (that pipeline lives elsewhere),
  /// keeping shift closure cheap on low-spec hardware. [lastModified] and
  /// [syncStatus] are retained so the offline-first sync engine still uploads
  /// the closure.
  Future<void> closeShift(ShiftsTableData activeShift) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.shiftsTable)
          ..where((t) => t.localId.equals(activeShift.localId)))
        .write(ShiftsTableCompanion(
      status: const Value(1),
      closedAt: Value(now),
      lastModified: Value(now),
      syncStatus: const Value('pending'),
    ));
  }
}
