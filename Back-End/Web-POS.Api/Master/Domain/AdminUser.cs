using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Master.Domain
{
    /// <summary>
    /// An operator account for the back-office admin portal (<c>/admin</c>).
    ///
    /// Lives in the MASTER database alongside <see cref="Tenant"/>, not in the
    /// tenant data: these accounts administer every company, so storing them in
    /// <c>web-pos</c> would put them inside the per-company cascade delete and
    /// scope them to a tenant they are supposed to sit above. They are unrelated
    /// to <c>PosUser</c>, which is a cashier of one company.
    ///
    /// The table is provisioned by docs/sql/master-db-schema.sql and self-healed
    /// at startup by <see cref="Api.Admin.AdminUserSeeder"/> — the master DB has
    /// no EF migrations.
    /// </summary>
    [Table("AdminUser")]
    public class AdminUser
    {
        [Key] public int Id { get; set; }

        [Required, MaxLength(100)]
        public string Username { get; set; } = default!;

        /// <summary>BCrypt hash. Never a plaintext or reversible value.</summary>
        [Required, MaxLength(255)]
        public string PasswordHash { get; set; } = default!;

        [MaxLength(255)]
        public string? DisplayName { get; set; }

        /// <summary>False locks the account out at login without deleting its history.</summary>
        public bool IsActive { get; set; } = true;

        /// <summary>
        /// Set on the seeded first admin, which ships with a password published in
        /// the source. Drives the standing banner in the portal shell and is cleared
        /// the moment the password is changed. It deliberately does NOT block login —
        /// an operator locked out of the portal cannot fix anything.
        /// </summary>
        public bool MustChangePassword { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime? LastLoginAt { get; set; }
    }
}
