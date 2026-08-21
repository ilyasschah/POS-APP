namespace Api.Domain;

/// <summary>
/// The POS session lifecycle, modelled on Odoo's.
///
/// 🚨 The two control states are NOT decoration. They are the states in which a
/// session exists but is not trading, and collapsing them into a bare
/// Open/Closed pair loses the two moments the cash actually gets verified:
///
///  * <see cref="OpeningControl"/> — the register is claimed for the day but the
///    opening float has not been confirmed yet. Selling is not allowed. This is
///    what stops a session existing with an unverified opening balance, which
///    would make every later expected-cash figure meaningless.
///  * <see cref="ClosingControl"/> — the cashier has asked to close, totals are
///    computed and shown, and the count is being entered. Selling stops HERE,
///    not at <see cref="Closed"/>, so a sale cannot land between "expected cash
///    was calculated" and "the drawer was counted" and silently invalidate the
///    reconciliation.
///
/// 🚨 The values start at 10, and that is load-bearing. `Shift.Status` already
/// ships as `0 = Open, 1 = Closed` for attendance shifts, and those rows live in
/// this same table. Numbering sessions 0–3 would have made `Status = 1` mean
/// "closed" for one shape and "OPENED — trading right now" for the other, so
/// every existing `WHERE Status = 1` would silently start matching live
/// sessions. Disjoint ranges make that class of mistake impossible instead of
/// merely documented:
///
///   0–1   attendance shift  (legacy, untouched)
///   10–13 POS session
/// </summary>
public static class PosSessionStatus
{
    /// <summary>Created; opening float not yet confirmed. No selling.</summary>
    public const int OpeningControl = 10;

    /// <summary>Trading. Sales, refunds and cash movements are allowed.</summary>
    public const int Opened = 11;

    /// <summary>Counting the drawer. Totals frozen; no new sales.</summary>
    public const int ClosingControl = 12;

    /// <summary>Finalised. Cannot reopen.</summary>
    public const int Closed = 13;

    /// <summary>
    /// States in which a device is considered to still hold a live session, and
    /// therefore may not open another. Includes <see cref="ClosingControl"/>:
    /// a half-closed register is still that register's session, and letting a
    /// second one open beside it is exactly how two sessions end up sharing a
    /// day's takings.
    /// </summary>
    public static readonly int[] Live = { OpeningControl, Opened, ClosingControl };

    public static bool IsLive(int status) => Array.IndexOf(Live, status) >= 0;

    public static string Name(int status) => status switch
    {
        OpeningControl => "OPENING_CONTROL",
        Opened => "OPENED",
        ClosingControl => "CLOSING_CONTROL",
        Closed => "CLOSED",
        _ => $"UNKNOWN({status})",
    };
}
