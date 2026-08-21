using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain;

/// <summary>
/// One row of the closing dialog: what a payment method was expected to hold,
/// what the cashier counted, and the difference — frozen at close.
///
/// Reconciliation is per METHOD, not cash-only: the closing screen lists Cash,
/// Bank/card and any other method side by side. Only cash is physically
/// counted; the others are confirmed, which still needs recording because
/// "confirmed 4,137.70" and "never looked at" are different statements.
///
/// 🚨 Separate from <c>ZReportPaymentSummary</c> on purpose. That row is the
/// REPORT's view of what was taken; this one is the COUNT the cashier signed
/// off. They can legitimately disagree (that disagreement is the whole point),
/// and merging them would destroy the evidence.
/// </summary>
[Table("PosSessionPaymentCount")]
public class PosSessionPaymentCount
{
    [Key]
    public int Id { get; private set; }

    public int CompanyId { get; private set; }

    /// <summary>The session (a <c>Shift</c> row with a PosDeviceId).</summary>
    public int SessionId { get; private set; }

    public int PaymentTypeId { get; private set; }

    /// <summary>What the system says this method took.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal Expected { get; private set; }

    /// <summary>What the cashier entered. Null = not counted/confirmed.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? Counted { get; private set; }

    /// <summary>Counted − Expected. Null while uncounted.</summary>
    [Column(TypeName = "decimal(18,2)")]
    public decimal? Difference { get; private set; }

    public DateTime DateCreated { get; private set; } = DateTime.UtcNow;

    public Shift? Session { get; private set; }
    public PaymentType? PaymentType { get; private set; }

    public PosSessionPaymentCount() { }

    public static PosSessionPaymentCount Create(
        int companyId,
        int sessionId,
        int paymentTypeId,
        decimal expected,
        decimal? counted)
    {
        if (companyId <= 0) throw new ArgumentException("Invalid CompanyId");
        if (sessionId <= 0) throw new ArgumentException("Invalid SessionId");
        if (paymentTypeId <= 0) throw new ArgumentException("Invalid PaymentTypeId");

        return new PosSessionPaymentCount
        {
            CompanyId = companyId,
            SessionId = sessionId,
            PaymentTypeId = paymentTypeId,
            Expected = expected,
            Counted = counted,
            Difference = counted.HasValue ? counted.Value - expected : null,
            DateCreated = DateTime.UtcNow,
        };
    }
}
