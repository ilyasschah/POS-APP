using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

/// <summary>
/// A working period. Two shapes share this table, told apart by
/// <see cref="PosDeviceId"/>:
///
///  * <b>POS SESSION</b> (<c>PosDeviceId != null</c>) — the trading period of one
///    register: opened, sold into by any number of cashiers, reconciled and
///    closed. This is the Odoo `pos.session` equivalent.
///  * <b>Attendance shift</b> (<c>PosDeviceId == null</c>) — an employee
///    clock-in, which predates sessions and is untouched by them. The client
///    already separates the two with its local <c>isDrawerShift</c> flag.
///
/// 🚨 Extended rather than replaced by a new `PosSession` entity, deliberately.
/// This table already carries OpenedAt/ClosedAt/StartingCash/ActualEndingCash/
/// Status plus the whole offline sync path (`pushPendingShifts`, localId,
/// syncStatus). A parallel entity would have duplicated all of it, and this
/// codebase has twice paid for duplicated concepts drifting apart.
/// </summary>
[Table("Shift")]
public class Shift : ISyncableEntity
{
    [Key]
    public int Id { get; private set; }

    public int CompanyId { get; private set; }

    /// <summary>Who OPENED the session. Not who sold — each order carries its
    /// own UserId, because a register is worked by several cashiers.</summary>
    public int UserId { get; private set; }

    /// <summary>
    /// The register this session belongs to. NULL for an attendance shift,
    /// which is what makes the two shapes separable without a discriminator
    /// column and without touching a single existing row.
    /// </summary>
    public int? PosDeviceId { get; private set; }

    /// <summary>
    /// Client-generated UUID, the idempotency key for offline pushes: a session
    /// opened with no connectivity is re-pushed until it lands, and matching on
    /// this is what stops the retry creating a second session. Same contract as
    /// `pos_orders.localId`. NULL for rows created server-side.
    /// </summary>
    [MaxLength(64)]
    public string? LocalId { get; private set; }

    public DateTime OpenedAt { get; private set; }
    public DateTime? ClosedAt { get; private set; }
    public int? ClosedByUserId { get; private set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal StartingCash { get; private set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal? ActualEndingCash { get; private set; }

    /// <summary>
    /// What the drawer SHOULD hold: opening + cash sales + cash in − cash out.
    /// Computed server-side at close and frozen, so the session report always
    /// reproduces the figure the cashier was shown rather than recomputing it
    /// against data that has moved since.
    /// </summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? ExpectedCash { get; private set; }

    /// <summary>Actual − expected. Stored rather than derived so a later
    /// correction cannot silently rewrite what was signed off.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? CashDifference { get; private set; }

    [MaxLength(1000)]
    public string? ClosingNote { get; private set; }

    /// <summary>Free text entered on the Opening Control screen.</summary>
    [MaxLength(1000)]
    public string? OpeningNote { get; private set; }

    /// <summary>
    /// Attendance shift: `0 = Open, 1 = Closed` (legacy, unchanged).
    /// POS session: <see cref="PosSessionStatus"/>, which uses 10–13 precisely
    /// so the two vocabularies can never be confused in a query.
    /// </summary>
    public int Status { get; private set; }

    // ── Force-close audit (admin-only escape hatch) ────────────────────────
    public bool ForceClosed { get; private set; }
    public int? ForceClosedByUserId { get; private set; }
    [MaxLength(500)]
    public string? ForceCloseReason { get; private set; }

    /// <summary>
    /// Set when a sale belonging to this session arrives AFTER it was closed —
    /// an offline device reconnecting. The session's own figures are never
    /// rewritten; this flags that a reconciliation record exists.
    /// </summary>
    public bool HasLateArrivals { get; private set; }

    public DateTime LastModified { get; set; } = DateTime.UtcNow;

    public PosDevice? PosDevice { get; private set; }

    public Shift() { }

    private Shift(int companyId, int userId, decimal startingCash)
    {
        CompanyId = companyId;
        UserId = userId;
        StartingCash = startingCash;
        OpenedAt = DateTime.UtcNow;
        Status = 0;
    }

    /// <summary>
    /// Attendance shift — the pre-existing behaviour, byte for byte. Callers
    /// that predate sessions (`ShiftsController`, the time clock) keep working
    /// with no change: no device, and Status 0 still means "not closed".
    /// </summary>
    public static Shift Create(int companyId, int userId, decimal startingCash)
    {
        if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
        if (userId <= 0) throw new ArgumentException("Invalid UserId");
        if (startingCash < 0) throw new ArgumentException("StartingCash cannot be negative");
        return new Shift(companyId, userId, startingCash);
    }

    /// <summary>
    /// Opens a POS SESSION on a register, in OPENING_CONTROL — deliberately not
    /// trading yet. <see cref="ConfirmOpening"/> is the second step, and it is
    /// what makes the opening float a verified number instead of an assumption.
    /// </summary>
    public static Shift OpenSession(
        int companyId,
        int userId,
        int posDeviceId,
        decimal openingCash,
        string? localId,
        DateTime? openedAt = null)
    {
        if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
        if (userId <= 0) throw new ArgumentException("Invalid UserId");
        if (posDeviceId <= 0) throw new ArgumentException("Invalid PosDeviceId");
        if (openingCash < 0) throw new ArgumentException("Opening cash cannot be negative");

        return new Shift(companyId, userId, openingCash)
        {
            PosDeviceId = posDeviceId,
            LocalId = string.IsNullOrWhiteSpace(localId) ? null : localId.Trim(),
            Status = PosSessionStatus.OpeningControl,
            // Honour the device's own clock for a session opened offline, so the
            // period matches the receipts it produced rather than the moment it
            // happened to reconnect.
            OpenedAt = openedAt ?? DateTime.UtcNow,
        };
    }

    /// <summary>OPENING_CONTROL → OPENED. Selling starts here.</summary>
    public void ConfirmOpening(decimal countedOpeningCash, string? openingNote = null)
    {
        if (Status != PosSessionStatus.OpeningControl)
            throw new InvalidOperationException(
                $"Session {Id} is {PosSessionStatus.Name(Status)}, not OPENING_CONTROL.");
        if (countedOpeningCash < 0)
            throw new InvalidOperationException("Opening cash cannot be negative.");

        StartingCash = countedOpeningCash;
        OpeningNote = Trim(openingNote, 1000) ?? OpeningNote;
        Status = PosSessionStatus.Opened;
    }

    /// <summary>
    /// OPENED → CLOSING_CONTROL. Selling stops immediately: the expected figure
    /// is about to be computed, and a sale landing after that point would make
    /// the count the cashier signs off wrong.
    /// </summary>
    public void EnterClosingControl(decimal expectedCash)
    {
        if (Status != PosSessionStatus.Opened)
            throw new InvalidOperationException(
                $"Session {Id} is {PosSessionStatus.Name(Status)}, not OPENED.");
        ExpectedCash = expectedCash;
        Status = PosSessionStatus.ClosingControl;
    }

    /// <summary>
    /// CLOSING_CONTROL → CLOSED with the counted drawer.
    ///
    /// Accepts an already-computed <paramref name="expectedCash"/> so the
    /// authority for the figure stays in one place (the service, against the
    /// database) rather than being recomputed from whatever the entity happens
    /// to hold.
    /// </summary>
    public void CloseSession(
        int closedByUserId,
        decimal expectedCash,
        decimal countedCash,
        string? closingNote)
    {
        if (Status == PosSessionStatus.Closed)
            throw new InvalidOperationException($"Session {Id} is already closed.");
        if (Status != PosSessionStatus.ClosingControl)
            throw new InvalidOperationException(
                $"Session {Id} is {PosSessionStatus.Name(Status)}; close it from CLOSING_CONTROL.");

        ExpectedCash = expectedCash;
        ActualEndingCash = countedCash;
        CashDifference = countedCash - expectedCash;
        ClosingNote = Trim(closingNote, 1000);
        ClosedByUserId = closedByUserId;
        ClosedAt = DateTime.UtcNow;
        Status = PosSessionStatus.Closed;
    }

    /// <summary>
    /// Admin-only escape hatch for a register that cannot close itself — lost,
    /// broken, or offline indefinitely.
    ///
    /// 🚨 Skips CLOSING_CONTROL on purpose: the whole point is that the device
    /// is unreachable, so nobody can count its drawer. The recorded reason and
    /// actor are the audit trail, and <see cref="HasLateArrivals"/> is how sales
    /// that turn up afterwards stay visible instead of silently rewriting this.
    /// </summary>
    public void ForceClose(int closedByUserId, string reason)
    {
        if (Status == PosSessionStatus.Closed)
            throw new InvalidOperationException($"Session {Id} is already closed.");
        if (string.IsNullOrWhiteSpace(reason))
            throw new InvalidOperationException("A force-close requires a reason.");

        ForceClosed = true;
        ForceClosedByUserId = closedByUserId;
        ForceCloseReason = Trim(reason, 500);
        ClosedByUserId = closedByUserId;
        ClosedAt = DateTime.UtcNow;
        Status = PosSessionStatus.Closed;
    }

    /// <summary>
    /// Records that a sale belonging to this session arrived after it closed.
    /// Only ever sets the flag — the session's money figures are frozen, and the
    /// difference is carried by a separate correction record.
    /// </summary>
    public void MarkLateArrival() => HasLateArrivals = true;

    /// <summary>Existing sync entry point for attendance shifts. Unchanged.</summary>
    public void SyncFrom(DateTime openedAt, DateTime? closedAt, decimal startingCash, decimal? actualEndingCash, int status)
    {
        OpenedAt = openedAt;
        ClosedAt = closedAt;
        StartingCash = startingCash;
        ActualEndingCash = actualEndingCash;
        Status = status;
    }

    public void Close(decimal actualEndingCash)
    {
        Status = 1;
        ClosedAt = DateTime.UtcNow;
        ActualEndingCash = actualEndingCash;
    }

    private static string? Trim(string? value, int max)
    {
        var v = value?.Trim();
        if (string.IsNullOrEmpty(v)) return null;
        return v.Length > max ? v[..max] : v;
    }
}
