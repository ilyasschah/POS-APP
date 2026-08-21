import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/session/pos_session_status.dart';

/// This terminal's stable GUID — the same value sent as `X-Device-Id` and the
/// same one the server maps to a `PosDevice` row.
final deviceUidProvider = FutureProvider<String>((ref) async {
  return AuthStorage().getOrCreateDeviceId();
});

/// The session THIS register is currently running, if any.
///
/// 🚨 Scoped by `posDeviceUid`, not by user. A session belongs to the register,
/// and several cashiers ring into it — that is the whole difference between a
/// session and the attendance shift stored in the same table. Attendance rows
/// have a null `posDeviceUid` and can never be returned here.
final activeSessionProvider = StreamProvider<ShiftsTableData?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  final uid = ref.watch(deviceUidProvider).value;
  if (companyId == null || uid == null) return Stream.value(null);

  return (db.select(db.shiftsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.posDeviceUid.equals(uid))
        ..where((t) => t.status.isIn(PosSessionStatus.live))
        ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
        ..limit(1))
      .watchSingleOrNull();
});

/// Whether this register may take money right now.
///
/// ⚠️ Reads as "the session says yes", NOT as a gate. Nothing enforces it yet —
/// the no-sale-without-session rule stays off until the offline round trip is
/// proven, by explicit instruction. When it is switched on, this is the single
/// place to consult, and it must keep a fail-open path: a register that cannot
/// resolve its session must never be stopped from trading.
final canSellProvider = Provider<bool>((ref) {
  final session = ref.watch(activeSessionProvider).value;
  return session != null && PosSessionStatus.canSell(session.status);
});

/// Session history for this company, newest first.
final sessionHistoryProvider =
    StreamProvider<List<ShiftsTableData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  return (db.select(db.shiftsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.posDeviceUid.isNotNull())
        ..orderBy([(t) => OrderingTerm.desc(t.openedAt)])
        ..limit(100))
      .watch();
});

final sessionNotifierProvider =
    NotifierProvider<SessionNotifier, void>(SessionNotifier.new);

/// Local session lifecycle. Writes Drift only — the push is Phase 5, and it
/// works from these rows exactly like every other offline entity.
class SessionNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(appDatabaseProvider);

  /// Opens a session on THIS register, in OPENING_CONTROL.
  ///
  /// 🚨 The `localId` minted here is the session's permanent identity and the
  /// idempotency key for its push. Orders, payments and cash movements store
  /// THIS value, never a server id — so a whole day rung up offline stays
  /// attached to the right session, and a re-pushed open returns the same
  /// session instead of creating a second (see `PosSessionService.OpenAsync`).
  ///
  /// Refuses if this register already has a live session: the caller should be
  /// offering "Continue selling" instead.
  Future<ShiftsTableData> openSession({
    required int companyId,
    required int userId,
    required String deviceUid,
    String? deviceName,
    double openingCash = 0,
  }) async {
    final existing = await _liveSessionFor(companyId, deviceUid);
    if (existing != null) {
      throw StateError(
        'This register already has a live session '
        '(${PosSessionStatus.name(existing.status)}). Continue selling in it, '
        'or close it first.',
      );
    }

    final now = DateTime.now().toUtc();
    final localId = const Uuid().v4();
    await _db.into(_db.shiftsTable).insert(
          ShiftsTableCompanion.insert(
            localId: localId,
            companyId: companyId,
            userId: userId,
            openedAt: now,
            lastModified: now,
            startingCash: Value(openingCash),
            posDeviceUid: Value(deviceUid),
            // The register's NAME as well as its uid: a session opened offline
            // has no server row to look it up from, and without it the history
            // reads "#00006" where it should read "POS1/00006". The pull
            // overwrites this with the server's copy once the session lands.
            posDeviceName:
                Value(deviceName?.trim().isEmpty ?? true ? null : deviceName!.trim()),
            status: const Value(PosSessionStatus.openingControl),
            syncStatus: const Value('pending_create'),
          ),
        );
    return (await _byLocalId(localId))!;
  }

  /// OPENING_CONTROL → OPENED with the counted opening float. Selling starts.
  Future<void> confirmOpening({
    required String localId,
    required double countedOpeningCash,
    String? openingNote,
  }) async {
    final session = await _requireSession(localId);
    if (session.status != PosSessionStatus.openingControl) {
      throw StateError(
        'Session is ${PosSessionStatus.name(session.status)}, '
        'not OPENING_CONTROL.',
      );
    }
    await _update(localId, ShiftsTableCompanion(
      // The COUNTED float replaces the expected one — that is the point of
      // opening control, and every later expected-cash figure builds on it.
      startingCash: Value(countedOpeningCash),
      openingNote: Value(openingNote),
      status: const Value(PosSessionStatus.opened),
    ));
  }

  /// OPENED → CLOSING_CONTROL. Selling stops here, not at CLOSED, so a sale
  /// cannot land between the expected figure being computed and the drawer
  /// being counted.
  Future<void> enterClosingControl({
    required String localId,
    required double expectedCash,
  }) async {
    final session = await _requireSession(localId);
    if (session.status != PosSessionStatus.opened) {
      throw StateError(
        'Session is ${PosSessionStatus.name(session.status)}, not OPENED.',
      );
    }
    await _update(localId, ShiftsTableCompanion(
      expectedCash: Value(expectedCash),
      status: const Value(PosSessionStatus.closingControl),
    ));
  }

  /// CLOSING_CONTROL → CLOSED with the counted drawer.
  Future<void> closeSession({
    required String localId,
    required int closedByUserId,
    required double expectedCash,
    required double countedCash,
    String? closingNote,
  }) async {
    final session = await _requireSession(localId);
    if (session.status == PosSessionStatus.closed) {
      throw StateError('This session is already closed.');
    }
    if (session.status != PosSessionStatus.closingControl) {
      throw StateError(
        'Session is ${PosSessionStatus.name(session.status)}; '
        'close it from CLOSING_CONTROL.',
      );
    }
    await _update(localId, ShiftsTableCompanion(
      expectedCash: Value(expectedCash),
      actualEndingCash: Value(countedCash),
      cashDifference: Value(countedCash - expectedCash),
      closingNote: Value(closingNote),
      closedByUserId: Value(closedByUserId),
      closedAt: Value(DateTime.now().toUtc()),
      status: const Value(PosSessionStatus.closed),
    ));
  }

  /// Marks a session force-closed locally, mirroring what the server recorded.
  /// Never originates here — a force-close is an admin action on the server,
  /// and this only reflects it so the register stops trading.
  Future<void> applyForceClose({
    required String localId,
    required int closedByUserId,
    required String reason,
  }) async {
    await _update(localId, ShiftsTableCompanion(
      forceClosed: const Value(true),
      forceClosedByUserId: Value(closedByUserId),
      forceCloseReason: Value(reason),
      closedByUserId: Value(closedByUserId),
      closedAt: Value(DateTime.now().toUtc()),
      status: const Value(PosSessionStatus.closed),
    ));
  }

  // ── internals ──────────────────────────────────────────────────────────

  Future<ShiftsTableData?> _byLocalId(String localId) =>
      (_db.select(_db.shiftsTable)..where((t) => t.localId.equals(localId)))
          .getSingleOrNull();

  Future<ShiftsTableData> _requireSession(String localId) async {
    final row = await _byLocalId(localId);
    if (row == null) throw StateError('Session $localId was not found.');
    return row;
  }

  Future<ShiftsTableData?> _liveSessionFor(int companyId, String deviceUid) =>
      (_db.select(_db.shiftsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.posDeviceUid.equals(deviceUid))
            ..where((t) => t.status.isIn(PosSessionStatus.live))
            ..limit(1))
          .getSingleOrNull();

  /// Every write re-marks the row pending so the push picks the change up —
  /// the same contract the rest of the offline entities follow.
  Future<void> _update(String localId, ShiftsTableCompanion changes) async {
    await (_db.update(_db.shiftsTable)
          ..where((t) => t.localId.equals(localId)))
        .write(changes.copyWith(
      lastModified: Value(DateTime.now().toUtc()),
      syncStatus: const Value('pending_create'),
    ));
  }
}
