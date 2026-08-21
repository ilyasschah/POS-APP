import 'package:pos_app/session/pos_session_status.dart';

/// One payment method's row in the closing dialog.
class SessionMethodTotal {
  const SessionMethodTotal({
    required this.paymentTypeId,
    required this.paymentTypeName,
    required this.isCash,
    required this.expected,
    this.counted,
  });

  final int paymentTypeId;
  final String paymentTypeName;

  /// Comes out of the cash drawer, so it is physically counted rather than
  /// merely confirmed.
  final bool isCash;

  final double expected;
  final double? counted;

  double? get difference => counted == null ? null : counted! - expected;

  SessionMethodTotal withCounted(double? value) => SessionMethodTotal(
        paymentTypeId: paymentTypeId,
        paymentTypeName: paymentTypeName,
        isCash: isCash,
        expected: expected,
        counted: value,
      );
}

/// Everything the closing screen shows, computed from local Drift rows.
///
/// 🚨 This is the OFFLINE mirror of `PosSessionService.BuildSummaryAsync`. The
/// server stays the authority — it recomputes on close and its figure is what
/// gets stored — but a register with no connectivity still has to be able to
/// count its drawer and shut down, so the same arithmetic has to exist here.
/// Both sides implement one formula:
///
///   expected cash = opening + cash payments + cash in − cash out
class SessionReconciliation {
  const SessionReconciliation({
    required this.openingCash,
    required this.cashPayments,
    required this.cashIn,
    required this.cashOut,
    required this.methods,
    required this.documentCount,
    this.countedCash,
    this.maxCashDifference = 10,
    this.cashMethodsConfigured = true,
    this.recordedExpectedCash,
  });

  final double openingCash;
  final double cashPayments;
  final double cashIn;
  final double cashOut;
  final List<SessionMethodTotal> methods;

  /// How many DOCUMENTS the session banked — not "orders".
  ///
  /// 🚨 A paid sale stops being an order the moment it is settled: checkout
  /// turns it into a document with payments against it, and the pos_order row
  /// is consumed. Counting orders therefore counts what is still UNPAID, which
  /// on a healthy session is zero — which is exactly the "0 orders" a till that
  /// sold all day was reporting.
  final int documentCount;

  /// What the cashier counted in the drawer. Null until they enter it.
  final double? countedCash;

  /// Above this, closing needs manager authorisation.
  final double maxCashDifference;

  /// The expected figure that was FROZEN when the session closed.
  ///
  /// 🚨 Authoritative from close onwards. Recomputing it afterwards from rows
  /// that have since been re-pulled can quietly disagree with the number the
  /// cashier signed off and the Z-report was built on — so once a session is
  /// CLOSED the stored number is what the screen shows, and the arithmetic
  /// below only ever runs for a session still open.
  final double? recordedExpectedCash;

  /// False when cash methods were inferred rather than configured — the screen
  /// should say so, because a mis-classified method moves money between
  /// "counted" and "confirmed".
  final bool cashMethodsConfigured;

  /// opening + cash payments + cash in − cash out, from the local rows.
  double get computedExpectedCash =>
      openingCash + cashPayments + cashIn - cashOut;

  double get expectedCash => recordedExpectedCash ?? computedExpectedCash;

  /// Everything taken across all methods — the dialog's header figure.
  double get totalTaken =>
      methods.fold<double>(0, (sum, m) => sum + m.expected);

  double? get cashDifference =>
      countedCash == null ? null : countedCash! - expectedCash;

  /// True when the drawer is off by more than the company's tolerance, so a
  /// manager has to authorise the close. Undefined (false) until counted.
  bool get needsManagerAuthorisation {
    final d = cashDifference;
    if (d == null) return false;
    return d.abs() > maxCashDifference;
  }

  SessionReconciliation withCountedCash(double? value) => SessionReconciliation(
        openingCash: openingCash,
        cashPayments: cashPayments,
        cashIn: cashIn,
        cashOut: cashOut,
        methods: methods,
        documentCount: documentCount,
        countedCash: value,
        maxCashDifference: maxCashDifference,
        cashMethodsConfigured: cashMethodsConfigured,
        recordedExpectedCash: recordedExpectedCash,
      );
}

/// Why a session cannot be closed yet.
///
/// 🚨 The DEVICE owns this list, not the server. Two of these are things the
/// server structurally cannot know — orders parked only in local Drift, and
/// sales still sitting in this terminal's push queue. Closing without checking
/// them produces a Z-report that omits sales which exist, which is the failure
/// the whole late-arrival mechanism exists to clean up after. Checking here is
/// how it is avoided rather than repaired.
class SessionCloseBlocker {
  const SessionCloseBlocker(this.kind, this.count);

  final SessionCloseBlockerKind kind;
  final int count;
}

enum SessionCloseBlockerKind {
  /// Orders parked on tables / held, still `status = 0`.
  openOrders,

  /// Completed sales this device has not pushed yet.
  unsyncedSales,

  /// The session is not in a state that can be closed.
  wrongState,
}

/// Whether these blockers permit a normal close.
bool canCloseNormally(List<SessionCloseBlocker> blockers) => blockers.isEmpty;

/// Whether a session in [status] may still take money.
bool sessionAcceptsSales(int? status) =>
    status != null && PosSessionStatus.canSell(status);
