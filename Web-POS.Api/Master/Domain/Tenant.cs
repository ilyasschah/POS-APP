using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Master.Domain
{
    /// <summary>
    /// Control-plane record for one customer business. Lives in the Master SaaS
    /// database (separate from tenant operational data), keyed back to the
    /// tenant-data <c>Company.Id</c> via <see cref="CompanyId"/>.
    /// </summary>
    [Table("Tenant")]
    public class Tenant
    {
        [Key] public int Id { get; set; }

        /// <summary>Foreign key into the tenant-data <c>Company.Id</c>.</summary>
        public int CompanyId { get; set; }

        [Required, MaxLength(255)]
        public string Name { get; set; } = default!;

        /// <summary>active | past_due | suspended | cancelled</summary>
        [MaxLength(30)]
        public string Status { get; set; } = "active";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>Set by the Pillar-5 clone auditor; non-null = needs admin review.</summary>
        public DateTime? ReviewFlaggedAt { get; set; }
    }
}
