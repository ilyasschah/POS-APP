using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Master.Domain
{
    /// <summary>
    /// One registered terminal per tenant. <see cref="DeviceId"/> is the hashed
    /// hardware fingerprint (Pillar 3). Seat enforcement (Pillar 4) counts
    /// <c>active</c> rows against the subscription's seat allowance.
    /// </summary>
    [Table("DeviceRegistry")]
    public class DeviceRegistry
    {
        [Key] public int Id { get; set; }

        public int TenantId { get; set; }
        public int CompanyId { get; set; }

        /// <summary>Hashed hardware fingerprint / device signature.</summary>
        [Required, MaxLength(128)]
        public string DeviceId { get; set; } = default!;

        [MaxLength(255)] public string? DeviceName { get; set; }

        /// <summary>
        /// active | inactive | blocked (+ 'revoked' on legacy rows only — a
        /// revoke now deletes the row). Only <c>active</c> counts against the
        /// subscription's seat allowance.
        /// </summary>
        [MaxLength(20)]
        public string Status { get; set; } = "active";

        public DateTime RegisteredAt { get; set; } = DateTime.UtcNow;
        public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
    }
}
