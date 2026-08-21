/// POS session lifecycle, mirroring `Api.Domain.PosSessionStatus` exactly.
///
/// 🚨 The values start at 10 and that is load-bearing on BOTH sides. The
/// `shifts` table holds attendance shifts too, and those use `0 = Open,
/// 1 = Closed`. If sessions were numbered 0–3, `status = 1` would mean "this
/// shift is closed" for one shape and "this register is trading right now" for
/// the other — and `activeShiftProvider`'s `status.equals(0)` would start
/// matching sessions. Disjoint ranges make that impossible:
///
///   0–1   attendance shift  (legacy, untouched)
///   10–13 POS session
///
/// Keep in step with the backend constant; a mismatch would let a device think
/// a session is trading when the server has it closing.
abstract final class PosSessionStatus {
  /// Created; opening float not confirmed yet. **No selling.**
  static const int openingControl = 10;

  /// Trading. Sales, refunds and cash movements are allowed.
  static const int opened = 11;

  /// Counting the drawer. Totals frozen; **no new sales.**
  static const int closingControl = 12;

  /// Finalised. Cannot reopen.
  static const int closed = 13;

  /// States in which a register still holds a live session and may not open
  /// another. Includes [closingControl]: a half-closed register is still that
  /// register's session.
  static const List<int> live = [openingControl, opened, closingControl];

  static bool isLive(int status) => live.contains(status);

  /// Whether a session in this state may take money.
  static bool canSell(int status) => status == opened;

  static String name(int status) => switch (status) {
        openingControl => 'OPENING_CONTROL',
        opened => 'OPENED',
        closingControl => 'CLOSING_CONTROL',
        closed => 'CLOSED',
        _ => 'UNKNOWN($status)',
      };
}
