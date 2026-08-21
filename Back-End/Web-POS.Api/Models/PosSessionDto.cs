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

    /// <summary>The terminal's stable GUID (same value as `X-Device-Id`).</summary>
    public string DeviceUid { get; set; } = string.Empty;

    /// <summary>Display name / numbering prefix, e.g. "POS1".</summary>
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
