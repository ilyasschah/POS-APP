using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Master.Domain
{
    /// <summary>
    /// Append-only, idempotent ledger of Stripe webhook events.
    /// <see cref="StripeEventId"/> is unique so a redelivered webhook is a no-op.
    /// </summary>
    [Table("BillingEvent")]
    public class BillingEvent
    {
        [Key] public int Id { get; set; }

        public int? TenantId { get; set; }

        [Required, MaxLength(100)]
        public string StripeEventId { get; set; } = default!;

        [MaxLength(100)] public string? Type { get; set; }

        public string? PayloadJson { get; set; }

        public DateTime ReceivedAt { get; set; } = DateTime.UtcNow;
    }
}
