namespace Api.Models;

/// <summary>A POS session as the client sees it.</summary>
public class PosSessionDto
{
    public int Id { get; set; }
    public string? LocalId { get; set; }
    public int CompanyId { get; set; }
    public int? PosDeviceId { get; set; }

    /// <summary>The register's name ("POS1"). Needed so a device can render
    /// ANOTHER register's sessions in the list without a second lookup.</summary>
    public string? PosDeviceName { get; set; }

    /// <summary>
    /// The REGISTER's uid — the value a terminal matches against its own
    /// `PosSession.RegisterUid` to decide "this is the session I am working".
    ///
    /// 🚨 Without it a session opened on another terminal arrives with no way
    /// to tell whether it belongs to this register, so a second device could
    /// never join it — it saw a list entry and nothing more.
    /// </summary>
    public string? PosDeviceUid { get; set; }
    public int OpenedByUserId { get; set; }
    public DateTime OpenedAt { get; set; }
    public int? ClosedByUserId { get; set; }
    public DateTime? ClosedAt { get; set; }
    public decimal OpeningCash { get; set; }
    public decimal? ExpectedCash { get; set; }
    public decimal? ActualEndingCash { get; set; }
    public decimal? CashDifference { get; set; }
    public string? ClosingNote { get; set; }
    public int Status { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public bool ForceClosed { get; set; }
    public int? ForceClosedByUserId { get; set; }
    public string? ForceCloseReason { get; set; }
    public bool HasLateArrivals { get; set; }
    public DateTime LastModified { get; set; }
}

/// <summary>One payment method's expected/counted row in the closing dialog.</summary>
public class PosSessionMethodDto
{
    public int PaymentTypeId { get; set; }
    public string PaymentTypeName { get; set; } = string.Empty;

    /// <summary>Comes out of the cash drawer, so it is physically counted.</summary>
    public bool IsCash { get; set; }

    public decimal Expected { get; set; }
    public decimal? Counted { get; set; }
    public decimal? Difference { get; set; }
}

/// <summary>Everything the closing screen needs, computed server-side.</summary>
public class PosSessionSummaryDto
{
    public int SessionId { get; set; }
    public int Status { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public DateTime OpenedAt { get; set; }
    public int OpenedByUserId { get; set; }

    public int OrderCount { get; set; }

    // expected cash = opening + cash payments + cash in − cash out
    public decimal OpeningCash { get; set; }
    public decimal CashPayments { get; set; }
    public decimal CashIn { get; set; }
    public decimal CashOut { get; set; }
    public decimal ExpectedCash { get; set; }

    /// <summary>Everything taken, all methods — the dialog's header figure.</summary>
    public decimal TotalTaken { get; set; }

    public List<PosSessionMethodDto> Methods { get; set; } = new();

    /// <summary>Above this, closing needs manager authorisation.</summary>
    public decimal MaxCashDifference { get; set; }

    /// <summary>
    /// False when the company has no `PosSession.CashPaymentTypeIds` and the
    /// cash methods were INFERRED. The closing screen should say so — an
    /// inferred classification moves money between "counted" and "confirmed".
    /// </summary>
    public bool CashMethodsConfigured { get; set; }
}

public class OpenPosSessionRequest
{
    /// <summary>Client UUID — the idempotency key for an offline open.</summary>
    public string? LocalId { get; set; }

    /// <summary>
    /// The REGISTER this session belongs to. Historically the terminal's own
    /// GUID — which is why one device got one register — but any stable uid the
    /// operator's chosen register carries. Two terminals sending the same value
    /// are working the same till and share its session.
    /// </summary>
    public string DeviceUid { get; set; } = string.Empty;

    /// <summary>The register's display name, e.g. "Front Till".</summary>
    public string? DeviceName { get; set; }

    public int UserId { get; set; }
    public decimal OpeningCash { get; set; }

    /// <summary>
    /// The device's own clock. Honoured so a session opened offline covers the
    /// period its receipts claim, not the moment it reconnected.
    /// </summary>
    public DateTime? OpenedAt { get; set; }
}

public class ConfirmOpeningRequest
{
    public int SessionId { get; set; }
    public decimal CountedOpeningCash { get; set; }
}

public class PosSessionCountInput
{
    public int PaymentTypeId { get; set; }
    public decimal? Counted { get; set; }
}

public class ClosePosSessionRequest
{
    public int SessionId { get; set; }
    public int UserId { get; set; }

    /// <summary>What was physically counted in the drawer.</summary>
    public decimal CountedCash { get; set; }

    /// <summary>Per-method counts/confirmations from the closing dialog.</summary>
    public List<PosSessionCountInput>? Counts { get; set; }

    public string? ClosingNote { get; set; }

    /// <summary>
    /// Set when a manager has authorised a difference beyond the company's
    /// tolerance. The server re-checks the tolerance regardless.
    /// </summary>
    public bool ManagerAuthorised { get; set; }
}

public class ForceClosePosSessionRequest
{
    public int SessionId { get; set; }
    public int UserId { get; set; }
    public string Reason { get; set; } = string.Empty;
}

/// <summary>
/// A device pushing its whole session state, for the offline sync path.
/// Replayable: sending it twice must change nothing the second time.
/// </summary>
public class SyncPosSessionRequest
{
    public string LocalId { get; set; } = string.Empty;
    public string DeviceUid { get; set; } = string.Empty;
    public string? DeviceName { get; set; }
    public int UserId { get; set; }
    public decimal OpeningCash { get; set; }
    public DateTime? OpenedAt { get; set; }

    /// <summary>Where the DEVICE believes the session got to (10–13).</summary>
    public int Status { get; set; }

    public int? ClosedByUserId { get; set; }

    /// <summary>What was counted in the drawer. Only the device knows this.</summary>
    public decimal? CountedCash { get; set; }

    public string? ClosingNote { get; set; }

    /// <summary>Free text from the Opening Control screen.</summary>
    public string? OpeningNote { get; set; }

    public List<PosSessionCountInput>? Counts { get; set; }
}

/// <summary>
/// A REGISTER — Odoo's `pos.config`. One named till with one drawer and one
/// session at a time; any number of terminals may work it at once.
///
/// 🚨 Stored in the `PosDevice` table, whose name predates the concept. It was
/// keyed by the terminal's own GUID, which is exactly why a session could not
/// be shared: every device silently created a register of its own. The uid is
/// now the REGISTER's, and an existing row is simply a register that happens to
/// be named after the one terminal that ever used it.
/// </summary>
public class PosRegisterDto
{
    public int Id { get; set; }
    public string Uid { get; set; } = string.Empty;
    public string? Name { get; set; }
    public DateTime LastSeenAt { get; set; }

    /// <summary>Live session on this register right now, if any — so the
    /// picker can say "Front Till · trading since 09:00" instead of a bare
    /// name, and a terminal joining knows what it is joining.</summary>
    public int? LiveSessionId { get; set; }
    public int? LiveSessionStatus { get; set; }
}

/// <summary>Create or rename a register.</summary>
public class UpsertPosRegisterRequest
{
    /// <summary>Stable id the terminals match on. Minted once, by whichever
    /// terminal first creates the register.</summary>
    public string Uid { get; set; } = string.Empty;

    public string? Name { get; set; }
}
