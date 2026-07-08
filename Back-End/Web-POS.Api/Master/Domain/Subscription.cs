using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Master.Domain
{
    /// <summary>
    /// Billing state for a tenant, linked to Stripe. <see cref="SeatAllowance"/>
    /// is the paid terminal cap enforced by Pillar 4; <see cref="CurrentPeriodEnd"/>
    /// drives the offline lease <c>validUntil</c> (Pillar 2).
    /// </summary>
    [Table("Subscription")]
    public class Subscription
    {
        [Key] public int Id { get; set; }

        public int TenantId { get; set; }

        [MaxLength(100)] public string? StripeCustomerId { get; set; }
        [MaxLength(100)] public string? StripeSubscriptionId { get; set; }
        [MaxLength(50)]  public string? PriceTier { get; set; }

        /// <summary>Paid terminal cap (e.g. 2). Enforced at the sync boundary.</summary>
        public int SeatAllowance { get; set; } = 1;

        public DateTime? CurrentPeriodEnd { get; set; }

        /// <summary>trialing | active | past_due | canceled | incomplete</summary>
        [MaxLength(30)]
        public string BillingStatus { get; set; } = "trialing";

        public DateTime LastModified { get; set; } = DateTime.UtcNow;
    }
}
