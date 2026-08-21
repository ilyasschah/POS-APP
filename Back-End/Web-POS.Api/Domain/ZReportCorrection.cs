using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

/// <summary>
/// Sales that reached the server AFTER their session was closed and reported —
/// an offline register reconnecting, usually after a force-close.
///
/// 🚨 This exists so that nothing has to choose between three bad options. When
/// a legitimate paid sale turns up late, the system must not:
///   * reject it — that strands real money on a device with no path to the
///     server, which is exactly the failure backlog item 33 was about;
///   * move it into the next session — the takings then land on the wrong day
///     and both sessions are wrong forever;
///   * silently rewrite the original Z-report — a report that has already been
///     printed, signed and filed cannot quietly change underneath the person
///     who filed it.
///
/// So the sale is accepted, keeps its original SessionId, and the DIFFERENCE is
/// recorded here as a correction pointing at the report it amends. The original
/// figures stay exactly as they were signed off; the correction is what the
/// operator (and the accountant) reconciles against.
///
/// One row accumulates per (session, original report): a device reconnecting in
/// several batches updates the counters rather than emitting a correction per
/// push, so the trail stays readable.
/// </summary>
[Table("ZReportCorrection")]
public class ZReportCorrection
{
    [Key]
    public int Id { get; private set; }

    public int CompanyId { get; private set; }

    /// <summary>The session whose sales arrived late.</summary>
    public int SessionId { get; private set; }

    /// <summary>
    /// The report this corrects. Nullable because a session can be force-closed
    /// before any Z-report was generated — the correction is still worth
    /// recording, it just has nothing to point at.
    /// </summary>
    public int? OriginalZReportId { get; private set; }

    public int LateOrderCount { get; private set; }

    [Column(TypeName = "decimal(18,2)")]
    public decimal LateAmount { get; private set; }

    /// <summary>Cash portion, which is what actually moves the drawer
    /// reconciliation. Card arriving late does not change the count.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal LateCashAmount { get; private set; }

    public DateTime FirstDetectedAt { get; private set; }
    public DateTime LastDetectedAt { get; private set; }

    /// <summary>Cleared by a human once the books have been squared.</summary>
    public bool Acknowledged { get; private set; }
    public int? AcknowledgedByUserId { get; private set; }
    public DateTime? AcknowledgedAt { get; private set; }

    public Shift? Session { get; private set; }

    public ZReportCorrection() { }

    public static ZReportCorrection Create(int companyId, int sessionId, int? originalZReportId)
    {
        if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
        if (sessionId <= 0) throw new ArgumentException("Invalid SessionId");

        var now = DateTime.UtcNow;
        return new ZReportCorrection
        {
            CompanyId = companyId,
            SessionId = sessionId,
            OriginalZReportId = originalZReportId,
            FirstDetectedAt = now,
            LastDetectedAt = now,
        };
    }

    /// <summary>Folds one more late sale into this correction.</summary>
    public void AddLateOrder(decimal amount, decimal cashAmount)
    {
        LateOrderCount += 1;
        LateAmount += amount;
        LateCashAmount += cashAmount;
        LastDetectedAt = DateTime.UtcNow;
        // A new arrival re-opens the question, even if someone had signed it off.
        Acknowledged = false;
        AcknowledgedByUserId = null;
        AcknowledgedAt = null;
    }

    public void Acknowledge(int userId)
    {
        Acknowledged = true;
        AcknowledgedByUserId = userId;
        AcknowledgedAt = DateTime.UtcNow;
    }
}
