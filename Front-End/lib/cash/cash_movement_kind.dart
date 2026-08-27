/// The kinds of row the `starting_cash` table holds.
///
/// 🚨 There are three, and the third one is the reason this file exists.
///
/// `in` and `out` are drawer movements DURING a shift, and every expected-cash
/// figure adds the first and subtracts the second:
///
/// ```
/// expectedCash = openingCash + cashPayments + cashIn - cashOut
/// ```
///
/// The opening float is already in that sum as `openingCash`, read from the
/// session's own `startingCash`. So writing it into this table as a plain `in`
/// would add the same money twice and every register would read over by the
/// float — which is precisely why it was left out of the table to begin with,
/// and why the cash-movement list could not show where the drawer started.
///
/// [opening] exists so the float can be a row like any other WITHOUT being
/// summed. Every consumer already branches explicitly on `in` / `out`
/// (`session_summary_provider.dart`, `z_report_service.dart`, and server-side
/// `PosSessionRepository` / `ZReportService`, which filter `StartingCashType ==
/// 0` and `== 1`), so an unrecognised third kind falls through all of them
/// untouched. That is the invariant this whole feature rests on: **never sum a
/// movement by "not out" — always name the kind you mean.**
abstract final class CashMovementKind {
  /// Cash added to the drawer mid-shift. Summed into `cashIn`.
  static const String cashIn = 'in';

  /// Cash removed from the drawer mid-shift. Summed into `cashOut`.
  static const String cashOut = 'out';

  /// The float counted into the drawer at opening control. Displayed, never
  /// summed — the session's `startingCash` is the figure the arithmetic uses.
  static const String opening = 'opening';

  /// Wire value for `StartingCash.StartingCashType` on the server.
  ///
  /// 0 and 1 are long-standing; 2 is new and every server-side sum already
  /// filters for 0 or 1 explicitly, so an older reader ignores it rather than
  /// misreading it as a cash-in.
  static int toApi(String kind) => switch (kind) {
        cashOut => 1,
        opening => 2,
        _ => 0,
      };

  /// Inverse of [toApi]. An unknown value reads as a cash-in, matching the
  /// server's own default.
  static String fromApi(int? value) => switch (value) {
        1 => cashOut,
        2 => opening,
        _ => cashIn,
      };
}
