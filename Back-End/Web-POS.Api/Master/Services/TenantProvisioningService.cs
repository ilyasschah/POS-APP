using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

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

        /// <summary>
        /// Releases a device's seat (sign-out): flips it to <c>inactive</c> so it no
        /// longer counts against the seat cap. Idempotent — unknown device is a no-op.
        /// The device is re-activated automatically on its next login/sync.
        /// </summary>
        Task ReleaseDeviceAsync(int companyId, string deviceId, CancellationToken ct = default);
    }

    public class TenantProvisioningService : ITenantProvisioningService
    {
        /// <summary>Length of the trial granted to a freshly provisioned tenant.</summary>
        private const int TrialDays = 30;

        private readonly MasterDbContext _db;
        private readonly int _staleDeviceDays;

        public TenantProvisioningService(MasterDbContext db, IConfiguration config)
        {
            _db = db;
            // Devices that haven't synced within this window are auto-released so a
            // crash / uninstall / offline sign-out never leaks a seat forever.
            _staleDeviceDays = config.GetValue<int?>("Seats:StaleDeviceDays") ?? 14;
        }

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

            // Reap leaked seats first: any 'active' device not seen within the stale
            // window (crash / uninstall / offline sign-out that never called release)
            // is flipped to 'inactive' so it no longer occupies a seat.
            await ReapStaleDevicesAsync(tenant.Id, ct);

            var existing = await _db.Devices
                .FirstOrDefaultAsync(d => d.TenantId == tenant.Id && d.DeviceId == deviceId, ct);

            var activeSeats = await _db.Devices
                .CountAsync(d => d.TenantId == tenant.Id && d.Status == "active", ct);

            // Known device.
            if (existing != null)
            {
                if (existing.Status == "blocked")
                    return new DeviceCheckResult(false, "device_blocked", activeSeats, allowance);

                // Reactivate a previously-released (or reaped) device, honouring the
                // cap — the seat it once held may have been taken by another terminal
                // while it was signed out. activeSeats already excludes this device.
                if (existing.Status != "active")
                {
                    if (activeSeats >= allowance)
                        return new DeviceCheckResult(false, "seat_limit_exceeded", activeSeats, allowance);

                    existing.Status = "active";
                    existing.LastSeenAt = DateTime.UtcNow;
                    await _db.SaveChangesAsync(ct);
                    return new DeviceCheckResult(true, "reactivated", activeSeats + 1, allowance);
                }

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

        public async Task ReleaseDeviceAsync(int companyId, string deviceId, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(deviceId)) return;

            var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null) return;

            var device = await _db.Devices
                .FirstOrDefaultAsync(d => d.TenantId == tenant.Id && d.DeviceId == deviceId, ct);

            // Don't touch a blocked device — an admin block must survive a sign-out.
            if (device == null || device.Status != "active") return;

            device.Status = "inactive";
            device.LastSeenAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
        }

        /// <summary>Flip 'active' devices that haven't been seen within the stale
        /// window to 'inactive', reclaiming seats leaked by crashes/uninstalls.</summary>
        private async Task ReapStaleDevicesAsync(int tenantId, CancellationToken ct)
        {
            var cutoff = DateTime.UtcNow.AddDays(-_staleDeviceDays);
            var stale = await _db.Devices
                .Where(d => d.TenantId == tenantId && d.Status == "active" && d.LastSeenAt < cutoff)
                .ToListAsync(ct);
            if (stale.Count == 0) return;

            foreach (var d in stale) d.Status = "inactive";
            await _db.SaveChangesAsync(ct);
        }
    }
}
