import '../core/formatters.dart';
import '../core/json_utils.dart';

/// The POS session lifecycle, mirroring `Api.Domain.PosSessionStatus` exactly.
///
/// The values start at 10 and that is load-bearing on the server: attendance
/// shifts live in the same `Shift` table and use `0 = Open, 1 = Closed`. If
/// sessions were numbered 0–3, `status == 1` would mean "closed" for one shape
/// and "trading right now" for the other. Disjoint ranges make that confusion
/// impossible:
///
///   0–1   attendance shift (legacy, not shown in this app)
///   10–13 POS session
enum PosSessionState {
  openingControl(10),
  opened(11),
  closingControl(12),
  closed(13),
  unknown(-1);

  const PosSessionState(this.code);

  final int code;

  static PosSessionState fromCode(int code) => switch (code) {
    10 => PosSessionState.openingControl,
    11 => PosSessionState.opened,
    12 => PosSessionState.closingControl,
    13 => PosSessionState.closed,
    _ => PosSessionState.unknown,
  };

  /// States in which a register still holds this session and may not open
  /// another — CLOSING_CONTROL included, because a half-closed register is
  /// still that register's session.
  bool get isLive =>
      this == PosSessionState.openingControl ||
      this == PosSessionState.opened ||
      this == PosSessionState.closingControl;

  String get title => switch (this) {
    PosSessionState.openingControl => 'Opening control',
    PosSessionState.opened => 'Trading',
    PosSessionState.closingControl => 'Counting drawer',
    PosSessionState.closed => 'Closed',
    PosSessionState.unknown => 'Unknown',
  };

  /// Short uppercase label for the status pill.
  String get badge => switch (this) {
    PosSessionState.openingControl => 'OPENING',
    PosSessionState.opened => 'LIVE',
    PosSessionState.closingControl => 'COUNTING',
    PosSessionState.closed => 'CLOSED',
    PosSessionState.unknown => 'UNKNOWN',
  };

  /// What the register may actually do in this state.
  String get explanation => switch (this) {
    PosSessionState.openingControl =>
      'Claimed for the day, opening float not confirmed yet. No selling.',
    PosSessionState.opened =>
      'Trading. Sales, refunds and cash movements are allowed.',
    PosSessionState.closingControl =>
      'Totals are frozen and the drawer is being counted. No new sales.',
    PosSessionState.closed => 'Finalised. This session cannot be reopened.',
    PosSessionState.unknown =>
      'Unrecognised status code — the app and the API may be out of step.',
  };
}

/// A row from `GET /PosSession/History` — mirrors
/// `Back-End/Web-POS.Api/Models/PosSessionDto.cs`.
///
/// Read-only everywhere in this app: sessions are opened, counted and closed
/// on the register that owns the drawer.
class PosSession {
  const PosSession({
    required this.id,
    required this.companyId,
    required this.openedByUserId,
    required this.openingCash,
    required this.status,
    required this.forceClosed,
    required this.hasLateArrivals,
    this.localId,
    this.posDeviceId,
    this.posDeviceName,
    this.openedAt,
    this.closedByUserId,
    this.closedAt,
    this.expectedCash,
    this.actualEndingCash,
    this.cashDifference,
    this.closingNote,
    this.statusName,
    this.forceClosedByUserId,
    this.forceCloseReason,
    this.lastModified,
  });

  final int id;

  /// The device's own UUID for this session — the idempotency key an offline
  /// register re-pushes until it lands.
  final String? localId;

  final int companyId;
  final int? posDeviceId;
  final String? posDeviceName;
  final int openedByUserId;
  final DateTime? openedAt;
  final int? closedByUserId;
  final DateTime? closedAt;
  final double openingCash;

  /// Frozen when the session entered CLOSING_CONTROL — the figure the cashier
  /// was actually held to, not a live recomputation.
  final double? expectedCash;

  /// What was physically counted in the drawer at close.
  final double? actualEndingCash;

  final double? cashDifference;
  final String? closingNote;
  final int status;
  final String? statusName;
  final bool forceClosed;
  final int? forceClosedByUserId;
  final String? forceCloseReason;

  /// A sale reached the server after this session closed. It kept this session
  /// and a Z-report correction was raised instead of rewriting the figures.
  final bool hasLateArrivals;

  final DateTime? lastModified;

  PosSessionState get state => PosSessionState.fromCode(status);

  bool get isLive => state.isLive;

  String get registerName {
    final name = posDeviceName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (posDeviceId != null) return 'Register #$posDeviceId';
    return 'Unknown register';
  }

  /// A live session has no end yet, so it is measured against now.
  Duration? get elapsed {
    final start = openedAt;
    if (start == null) return null;
    return (closedAt ?? DateTime.now()).difference(start);
  }

  /// Anything rounding can produce is not a real difference.
  bool get hasCashDifference => (cashDifference ?? 0).abs() >= 0.005;

  bool get needsAttention => forceClosed || hasLateArrivals || hasCashDifference;

  factory PosSession.fromJson(Map<String, dynamic> json) => PosSession(
    id: asInt(json['id']),
    localId: asStringOrNull(json['localId']),
    companyId: asInt(json['companyId']),
    posDeviceId: asIntOrNull(json['posDeviceId']),
    posDeviceName: asStringOrNull(json['posDeviceName']),
    openedByUserId: asInt(json['openedByUserId']),
    // Session timestamps are written with DateTime.UtcNow — see
    // Fmt.parseUtcDate for why they need a different parser to document dates.
    openedAt: Fmt.parseUtcDate(json['openedAt']),
    closedByUserId: asIntOrNull(json['closedByUserId']),
    closedAt: Fmt.parseUtcDate(json['closedAt']),
    openingCash: asDouble(json['openingCash']),
    expectedCash: asDoubleOrNull(json['expectedCash']),
    actualEndingCash: asDoubleOrNull(json['actualEndingCash']),
    cashDifference: asDoubleOrNull(json['cashDifference']),
    closingNote: asStringOrNull(json['closingNote']),
    status: asInt(json['status'], -1),
    statusName: asStringOrNull(json['statusName']),
    forceClosed: asBool(json['forceClosed']),
    forceClosedByUserId: asIntOrNull(json['forceClosedByUserId']),
    forceCloseReason: asStringOrNull(json['forceCloseReason']),
    hasLateArrivals: asBool(json['hasLateArrivals']),
    lastModified: Fmt.parseUtcDate(json['lastModified']),
  );
}

/// One payment method's row in the reconciliation.
class PosSessionMethod {
  const PosSessionMethod({
    required this.paymentTypeId,
    required this.isCash,
    required this.expected,
    this.paymentTypeName,
    this.counted,
    this.difference,
  });

  final int paymentTypeId;
  final String? paymentTypeName;

  /// Comes out of the cash drawer, so it is physically counted rather than
  /// merely confirmed.
  final bool isCash;

  final double expected;

  // `/Summary` recomputes expectations live and leaves these null; they are
  // modelled because the DTO carries them and are rendered only when present.
  final double? counted;
  final double? difference;

  String get name => paymentTypeName?.trim().isNotEmpty == true
      ? paymentTypeName!.trim()
      : 'Method #$paymentTypeId';

  factory PosSessionMethod.fromJson(Map<String, dynamic> json) =>
      PosSessionMethod(
        paymentTypeId: asInt(json['paymentTypeId']),
        paymentTypeName: asStringOrNull(json['paymentTypeName']),
        isCash: asBool(json['isCash']),
        expected: asDouble(json['expected']),
        counted: asDoubleOrNull(json['counted']),
        difference: asDoubleOrNull(json['difference']),
      );
}

/// `GET /PosSession/Summary` — everything the closing screen computes
/// server-side.
///
/// Recomputed against the database on every call, so for a CLOSED session it
/// can legitimately disagree with the frozen figures on the session row. That
/// disagreement is late sales, and it is surfaced rather than hidden.
class PosSessionSummary {
  const PosSessionSummary({
    required this.sessionId,
    required this.status,
    required this.orderCount,
    required this.openingCash,
    required this.cashPayments,
    required this.cashIn,
    required this.cashOut,
    required this.expectedCash,
    required this.totalTaken,
    required this.methods,
    required this.maxCashDifference,
    required this.cashMethodsConfigured,
    this.statusName,
    this.openedAt,
    this.openedByUserId,
  });

  final int sessionId;
  final int status;
  final String? statusName;
  final DateTime? openedAt;
  final int? openedByUserId;

  /// Documents banked, not PosOrders — checkout consumes the order row, so
  /// counting orders would report 0 for a till that sold all day.
  final int orderCount;

  final double openingCash;
  final double cashPayments;
  final double cashIn;
  final double cashOut;

  /// opening + cash payments + cash in − cash out.
  final double expectedCash;

  /// Everything taken, all methods.
  final double totalTaken;

  final List<PosSessionMethod> methods;

  /// Above this, closing needs manager authorisation.
  final double maxCashDifference;

  /// False when the company never set `PosSession.CashPaymentTypeIds` and the
  /// cash methods were INFERRED — worth saying out loud, because it moves
  /// money between "counted" and merely "confirmed".
  final bool cashMethodsConfigured;

  double get averageSale => orderCount <= 0 ? 0 : totalTaken / orderCount;

  factory PosSessionSummary.fromJson(Map<String, dynamic> json) =>
      PosSessionSummary(
        sessionId: asInt(json['sessionId']),
        status: asInt(json['status'], -1),
        statusName: asStringOrNull(json['statusName']),
        openedAt: Fmt.parseUtcDate(json['openedAt']),
        openedByUserId: asIntOrNull(json['openedByUserId']),
        orderCount: asInt(json['orderCount']),
        openingCash: asDouble(json['openingCash']),
        cashPayments: asDouble(json['cashPayments']),
        cashIn: asDouble(json['cashIn']),
        cashOut: asDouble(json['cashOut']),
        expectedCash: asDouble(json['expectedCash']),
        totalTaken: asDouble(json['totalTaken']),
        methods: asList(json['methods'], PosSessionMethod.fromJson),
        maxCashDifference: asDouble(json['maxCashDifference']),
        cashMethodsConfigured: asBool(json['cashMethodsConfigured'], true),
      );
}
