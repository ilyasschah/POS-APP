using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Master
{
    /// <summary>
    /// The SaaS control plane (Pillar 1). Kept as a SEPARATE DbContext / database
    /// from the tenant operational data (<c>AppDbContext</c>) so the per-company
    /// cascade delete can never touch billing/device records, and so it can be
    /// hosted cloud-only later without moving tenant data.
    /// Point it at its own catalog via the <c>MasterConnection</c> connection string.
    /// </summary>
    public class MasterDbContext : DbContext
    {
        public MasterDbContext(DbContextOptions<MasterDbContext> options) : base(options) { }

        public DbSet<Tenant> Tenants => Set<Tenant>();
        public DbSet<Subscription> Subscriptions => Set<Subscription>();
        public DbSet<DeviceRegistry> Devices => Set<DeviceRegistry>();
        public DbSet<BillingEvent> BillingEvents => Set<BillingEvent>();
        public DbSet<TransactionAudit> TransactionAudits => Set<TransactionAudit>();

        protected override void OnModelCreating(ModelBuilder b)
        {
            base.OnModelCreating(b);

            b.Entity<Tenant>().HasIndex(t => t.CompanyId).IsUnique();
            b.Entity<Subscription>().HasIndex(s => s.TenantId).IsUnique();
            b.Entity<DeviceRegistry>().HasIndex(d => new { d.TenantId, d.DeviceId }).IsUnique();
            b.Entity<BillingEvent>().HasIndex(e => e.StripeEventId).IsUnique();
            b.Entity<TransactionAudit>().HasIndex(a => new { a.TenantId, a.ClientTxnId }).IsUnique();
        }
    }
}
