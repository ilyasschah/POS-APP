using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Master.Domain
{
    /// <summary>
    /// Pillar 5 — clone / duplication audit ledger. One row per client-generated
    /// transaction id (<c>LocalId</c> UUID) ever seen for a tenant. A LocalId is
    /// minted exactly once, on the single device that created the order — so the
    /// SAME LocalId arriving from a DIFFERENT device signals that a terminal's
    /// local data was duplicated onto another device (a clone / restored backup).
    /// Such rows are flagged for the operator; detection only — never blocks sync.
    /// </summary>
    [Table("TransactionAudit")]
    public class TransactionAudit
    {
        [Key] public int Id { get; set; }

        public int TenantId { get; set; }
        public int CompanyId { get; set; }

        /// <summary>The client-minted transaction id (PosOrder <c>LocalId</c> UUID).</summary>
        [Required, MaxLength(128)]
        public string ClientTxnId { get; set; } = default!;

        /// <summary>Device that first reported this transaction (the legitimate origin).</summary>
        [Required, MaxLength(128)]
        public string FirstDeviceId { get; set; } = default!;

        /// <summary>Most recent device to report it (differs from first → clone signal).</summary>
        [MaxLength(128)]
        public string? LastDeviceId { get; set; }

        public int SeenCount { get; set; } = 1;

        /// <summary>True once the same txn id was reported by a second device.</summary>
        public bool IsFlagged { get; set; }

        /// <summary>e.g. <c>cross_device_duplicate</c>.</summary>
        [MaxLength(64)]
        public string? FlagReason { get; set; }

        public DateTime FirstSeenUtc { get; set; } = DateTime.UtcNow;
        public DateTime LastSeenUtc { get; set; } = DateTime.UtcNow;
    }
}
