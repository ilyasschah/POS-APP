using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Master.Services
{
    /// <summary>Result of a device registration / seat-cap check (Pillar 4).</summary>
    public record DeviceCheckResult(bool Allowed, string Reason, int ActiveSeats, int SeatAllowance);

    public interface ITenantProvisioningService
    {
        /// <summary>Creates the Tenant + default Subscription for a company if missing (idempotent).</summary>
        Task<Tenant> ProvisionTenantAsync(int companyId, string name, int seatAllowance = 1, int subscriptionDays = 30, CancellationToken ct = default);

        /// <summary>Removes the Tenant for a company (cascades subscription + devices). Idempotent.</summary>
        Task DeprovisionTenantAsync(int companyId, CancellationToken ct = default);

        /// <summary>
        /// Registers a device for the company, or — if it would exceed the paid
        /// seat allowance — refuses it. Existing/known devices are always allowed
        /// and have their LastSeenAt bumped. This is the Pillar-4 primitive that
        /// the sync ingress will call before accepting a push.
        /// </summary>
        Task<DeviceCheckResult> RegisterOrValidateDeviceAsync(int companyId, string deviceId, string? deviceName, CancellationToken ct = default);
    }

    public class TenantProvisioningService : ITenantProvisioningService
    {
        /// <summary>Length of the trial granted to a freshly provisioned tenant.</summary>
        private const int TrialDays = 30;

        private readonly MasterDbContext _db;
        public TenantProvisioningService(MasterDbContext db) => _db = db;

        public async Task<Tenant> ProvisionTenantAsync(int companyId, string name, int seatAllowance = 1, int subscriptionDays = TrialDays, CancellationToken ct = default)
        {
            var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null)
            {
                tenant = new Tenant { CompanyId = companyId, Name = name, Status = "active" };
                _db.Tenants.Add(tenant);
                await _db.SaveChangesAsync(ct);

                _db.Subscriptions.Add(new Subscription
                {
                    TenantId = tenant.Id,
                    SeatAllowance = seatAllowance,
                    BillingStatus = "trialing",
                    CurrentPeriodEnd = DateTime.UtcNow.AddDays(subscriptionDays),
                });
                await _db.SaveChangesAsync(ct);
            }
            return tenant;
        }

        public async Task DeprovisionTenantAsync(int companyId, CancellationToken ct = default)
        {
            // Pillar 5 audit rows have no FK to Tenant, so clear them explicitly.
            var audits = await _db.TransactionAudits.Where(a => a.CompanyId == companyId).ToListAsync(ct);
            if (audits.Count > 0) _db.TransactionAudits.RemoveRange(audits);

            var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant != null)
                _db.Tenants.Remove(tenant); // FK ON DELETE CASCADE removes its subscription + devices

            if (audits.Count > 0 || tenant != null)
                await _db.SaveChangesAsync(ct);
        }

        public async Task<DeviceCheckResult> RegisterOrValidateDeviceAsync(int companyId, string deviceId, string? deviceName, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(deviceId))
                return new DeviceCheckResult(false, "missing_device_id", 0, 0);

            var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null)
                return new DeviceCheckResult(false, "tenant_not_provisioned", 0, 0);

            var sub = await _db.Subscriptions.FirstOrDefaultAsync(s => s.TenantId == tenant.Id, ct);
            var allowance = sub?.SeatAllowance ?? 1;

            var existing = await _db.Devices
                .FirstOrDefaultAsync(d => d.TenantId == tenant.Id && d.DeviceId == deviceId, ct);

            var activeSeats = await _db.Devices
                .CountAsync(d => d.TenantId == tenant.Id && d.Status == "active", ct);

            // Known device: allow (unless explicitly blocked) and refresh last-seen.
            if (existing != null)
            {
                if (existing.Status == "blocked")
                    return new DeviceCheckResult(false, "device_blocked", activeSeats, allowance);

                existing.LastSeenAt = DateTime.UtcNow;
                await _db.SaveChangesAsync(ct);
                return new DeviceCheckResult(true, "known_device", activeSeats, allowance);
            }

            // New device: enforce the seat cap.
            if (activeSeats >= allowance)
                return new DeviceCheckResult(false, "seat_limit_exceeded", activeSeats, allowance);

            _db.Devices.Add(new DeviceRegistry
            {
                TenantId = tenant.Id,
                CompanyId = companyId,
                DeviceId = deviceId,
                DeviceName = deviceName,
                Status = "active",
            });
            await _db.SaveChangesAsync(ct);
            return new DeviceCheckResult(true, "registered", activeSeats + 1, allowance);
        }
    }
}
