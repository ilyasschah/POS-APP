using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Api.Master.Services
{
    /// <summary>Result of a device registration / seat-cap check (Pillar 4).</summary>
    public record DeviceCheckResult(bool Allowed, string Reason, int ActiveSeats, int SeatAllowance);

    /// <summary>Outcome of <see cref="ITenantProvisioningService.RenameDeviceAsync"/>.</summary>
    public enum DeviceRenameOutcome { Renamed, Unchanged, NotFound, NameTaken }

    /// <summary>One terminal registered to an account, as the POS device list shows it.</summary>
    public record AccountDevice(string DeviceId, string? DeviceName, string Status, DateTime RegisteredAt, DateTime LastSeenAt);

    /// <summary>
    /// Every terminal registered to a company, with the same seat figures the
    /// admin portal shows ("3 / 7").
    /// </summary>
    public record AccountDevicesResult(int SeatAllowance, int ActiveSeats, IReadOnlyList<AccountDevice> Devices);

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
        /// <param name="isInteractiveLogin">
        /// True only for a master login, where the operator has just proved they
        /// hold the account credentials. **Enrollment happens there and nowhere
        /// else**: an unknown device on any other path (sync ingress, CheckDevice)
        /// is refused as <c>device_revoked</c> rather than registered. That is what
        /// makes <see cref="RevokeDeviceAsync"/>'s row deletion stick — otherwise a
        /// revoked terminal would silently re-register on its next sync. It also
        /// clears a legacy <c>revoked</c> row, so such a terminal signs back in.
        /// </param>
        Task<DeviceCheckResult> RegisterOrValidateDeviceAsync(int companyId, string deviceId, string? deviceName, CancellationToken ct = default, bool isInteractiveLogin = false);

        /// <summary>
        /// Releases a device's seat (sign-out): flips it to <c>inactive</c> so it no
        /// longer counts against the seat cap. Idempotent — unknown device is a no-op.
        /// The device is re-activated automatically on its next login/sync.
        /// </summary>
        Task ReleaseDeviceAsync(int companyId, string deviceId, CancellationToken ct = default);

        /// <summary>
        /// Administratively revokes a terminal (User info → Active devices): the
        /// registry row is DELETED, freeing its seat. Unlike
        /// <see cref="ReleaseDeviceAsync"/> it is not silently undone by the
        /// device's next sync — an unknown device is refused on every
        /// non-interactive path, which is what makes the terminal sign out and ask
        /// for the account credentials again. A fresh master login re-enrolls it,
        /// subject to the seat cap. A <c>blocked</c> device is left alone: its ban
        /// is remembered only by its row.
        /// </summary>
        Task<bool> RevokeDeviceAsync(int companyId, string deviceId, CancellationToken ct = default);

        /// <summary>
        /// Sets the operator-facing name of a terminal ("POS1", "CAISSE2") without
        /// touching its seat state. The name is the POS name the terminal already
        /// keeps device-locally and uses as its document-number prefix, so the
        /// admin lists a device by the label the venue actually calls it instead
        /// of a 40-character UUID. Blank is ignored (never blanks an existing
        /// name) and, like an unknown device, reports <see cref="DeviceRenameOutcome.NotFound"/>.
        /// A name another terminal of the same account already carries is refused
        /// with <see cref="DeviceRenameOutcome.NameTaken"/> — see <see cref="IsDeviceNameAvailableAsync"/>.
        /// </summary>
        Task<DeviceRenameOutcome> RenameDeviceAsync(int companyId, string deviceId, string? deviceName, CancellationToken ct = default);

        /// <summary>
        /// True when no OTHER terminal of the company carries <paramref name="deviceName"/>
        /// (case-insensitive). The name is the terminal's document-number prefix, so
        /// two tills sharing one would issue colliding numbers offline — the exact
        /// thing the prefix exists to prevent.
        ///
        /// Every registered row counts, <c>inactive</c> and <c>blocked</c> included:
        /// a released or reaped terminal still exists and can come back. Only a
        /// legacy <c>revoked</c> tombstone frees its name. To reuse the name of a
        /// dead install, revoke that terminal first (User info → Active devices).
        /// </summary>
        Task<bool> IsDeviceNameAvailableAsync(int companyId, string deviceId, string deviceName, CancellationToken ct = default);

        /// <summary>
        /// DeviceId → DeviceName for every registered terminal of a company, so a
        /// caller in the *app* database can label its device rows. Devices with no
        /// name recorded are omitted, letting the caller fall back to the id.
        /// </summary>
        Task<Dictionary<string, string>> GetDeviceNamesAsync(int companyId, CancellationToken ct = default);

        /// <summary>
        /// Every terminal registered to the company — whatever its status, and
        /// whoever has a PIN on it — plus the seat allowance. This is the
        /// account's device list; the PIN table only knows which terminals a
        /// given USER has set a PIN on, which is not the same list at all.
        /// </summary>
        Task<AccountDevicesResult> GetAccountDevicesAsync(int companyId, CancellationToken ct = default);
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

        public async Task<DeviceCheckResult> RegisterOrValidateDeviceAsync(int companyId, string deviceId, string? deviceName, CancellationToken ct = default, bool isInteractiveLogin = false)
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

                // LEGACY rows only — a revoke now deletes the row outright, so
                // nothing writes this status any more. Kept because devices
                // revoked before that change still carry it, and they must keep
                // behaving the same: refused for sync/SeatGuard so the terminal
                // signs out, cleared only by a real master login.
                if (existing.Status == "revoked" && !isInteractiveLogin)
                    return new DeviceCheckResult(false, "device_revoked", activeSeats, allowance);

                // Reactivate a previously-released (or reaped) device, honouring the
                // cap — the seat it once held may have been taken by another terminal
                // while it was signed out. activeSeats already excludes this device.
                if (existing.Status != "active")
                {
                    if (activeSeats >= allowance)
                        return new DeviceCheckResult(false, "seat_limit_exceeded", activeSeats, allowance);

                    existing.Status = "active";
                    existing.LastSeenAt = DateTime.UtcNow;
                    await ApplyDeviceNameAsync(existing, deviceName, ct);
                    await _db.SaveChangesAsync(ct);
                    return new DeviceCheckResult(true, "reactivated", activeSeats + 1, allowance);
                }

                existing.LastSeenAt = DateTime.UtcNow;
                // A terminal renamed in Settings carries the new name on its next
                // login/sync — without this the registry kept whatever it was first
                // registered with, forever.
                await ApplyDeviceNameAsync(existing, deviceName, ct);
                await _db.SaveChangesAsync(ct);
                return new DeviceCheckResult(true, "known_device", activeSeats, allowance);
            }

            // ── Unknown device ────────────────────────────────────────────────
            // 🚨 A terminal may only ENROLL through a master login, where the
            // operator has just proved they hold the account credentials. This is
            // what makes RevokeDeviceAsync's row deletion safe: a revoked device
            // is unknown on its next sync, and if it could register itself here it
            // would silently take a free seat and carry on trading — the revoke
            // would do nothing at all.
            //
            // Reported as 'device_revoked' because that is what it means to the
            // terminal and to the operator ("you were removed, sign in again"),
            // and the client already routes that to master login. A device can
            // never legitimately reach a sync ingress without a row: the row is
            // created by /Auth/Login, and sync needs the token that login issues.
            if (!isInteractiveLogin)
                return new DeviceCheckResult(false, "device_revoked", activeSeats, allowance);

            // New device: enforce the seat cap.
            if (activeSeats >= allowance)
                return new DeviceCheckResult(false, "seat_limit_exceeded", activeSeats, allowance);

            // A name another terminal already carries is not adopted — the row is
            // enrolled unnamed and the operator picks a free name in onboarding.
            // Refusing the LOGIN over a label would lock a paying till out.
            var name = NormalizeDeviceName(deviceName);
            if (name != null && await IsNameHeldByAnotherDeviceAsync(tenant.Id, deviceId, name, ct))
                name = null;

            _db.Devices.Add(new DeviceRegistry
            {
                TenantId = tenant.Id,
                CompanyId = companyId,
                DeviceId = deviceId,
                DeviceName = name,
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

        public async Task<bool> RevokeDeviceAsync(int companyId, string deviceId, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(deviceId)) return false;

            var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null) return false;

            var device = await _db.Devices
                .FirstOrDefaultAsync(d => d.TenantId == tenant.Id && d.DeviceId == deviceId, ct);
            if (device == null) return false;

            // A blocked device stays blocked — an admin block outranks a revoke,
            // and it must NOT be deleted: a block is remembered only by its row,
            // so removing it would let the device re-enroll at the next master
            // login and quietly undo the ban.
            if (device.Status == "blocked") return true;

            // The row is DELETED (user's explicit call — it used to be flipped to
            // 'revoked' and kept). Keeping a tombstone was what stopped the device
            // re-registering itself; that job now belongs to the unknown-device
            // branch of RegisterOrValidateDeviceAsync, which refuses to enroll
            // anything outside an interactive master login. Both halves are
            // required — deleting the row without that branch silently re-admits
            // every revoked terminal on its next sync.
            _db.Devices.Remove(device);
            await _db.SaveChangesAsync(ct);
            return true;
        }

        public async Task<DeviceRenameOutcome> RenameDeviceAsync(int companyId, string deviceId, string? deviceName, CancellationToken ct = default)
        {
            var clean = NormalizeDeviceName(deviceName);
            if (string.IsNullOrWhiteSpace(deviceId) || clean == null) return DeviceRenameOutcome.NotFound;

            var tenant = await _db.Tenants.FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null) return DeviceRenameOutcome.NotFound;

            var device = await _db.Devices
                .FirstOrDefaultAsync(d => d.TenantId == tenant.Id && d.DeviceId == deviceId, ct);
            if (device == null) return DeviceRenameOutcome.NotFound;

            // Rename only. Status and LastSeenAt are seat state and are deliberately
            // NOT touched: renaming a terminal must never reactivate a released one
            // or make a stale device look alive to the reaper.
            if (device.DeviceName == clean) return DeviceRenameOutcome.Unchanged;

            if (await IsNameHeldByAnotherDeviceAsync(tenant.Id, deviceId, clean, ct))
                return DeviceRenameOutcome.NameTaken;

            device.DeviceName = clean;
            await _db.SaveChangesAsync(ct);
            return DeviceRenameOutcome.Renamed;
        }

        public async Task<bool> IsDeviceNameAvailableAsync(int companyId, string deviceId, string deviceName, CancellationToken ct = default)
        {
            var clean = NormalizeDeviceName(deviceName);
            if (clean == null) return false;

            var tenant = await _db.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null) return true;

            return !await IsNameHeldByAnotherDeviceAsync(tenant.Id, deviceId, clean, ct);
        }

        public async Task<AccountDevicesResult> GetAccountDevicesAsync(int companyId, CancellationToken ct = default)
        {
            var tenant = await _db.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.CompanyId == companyId, ct);
            if (tenant == null) return new AccountDevicesResult(0, 0, Array.Empty<AccountDevice>());

            var sub = await _db.Subscriptions.AsNoTracking().FirstOrDefaultAsync(s => s.TenantId == tenant.Id, ct);

            // A read: stale devices are NOT reaped here. The list shows what the
            // seat check would see before its own reap on the next login/sync.
            var rows = await _db.Devices.AsNoTracking()
                .Where(d => d.TenantId == tenant.Id)
                .OrderBy(d => d.Status == "active" ? 0 : 1)
                .ThenBy(d => d.RegisteredAt)
                .ToListAsync(ct);

            var devices = rows
                .Select(d => new AccountDevice(
                    d.DeviceId,
                    IsRealDeviceName(d.DeviceName) ? d.DeviceName : null,
                    d.Status,
                    d.RegisteredAt,
                    d.LastSeenAt))
                .ToList();

            return new AccountDevicesResult(
                sub?.SeatAllowance ?? 1,
                rows.Count(d => d.Status == "active"),
                devices);
        }

        /// <summary>
        /// The constant every device was registered with before terminals reported
        /// their own name. It is not a name — it labelled every row identically,
        /// which is the whole problem — so it is treated as "unnamed" and the UI
        /// falls back to the id until that terminal next logs in or syncs. A real
        /// POS name can never collide with it: names are stripped to A–Z0–9.
        /// </summary>
        private const string LegacyDeviceNamePlaceholder = "POS terminal";

        private static bool IsRealDeviceName(string? name) =>
            !string.IsNullOrEmpty(name) && name != LegacyDeviceNamePlaceholder;

        public async Task<Dictionary<string, string>> GetDeviceNamesAsync(int companyId, CancellationToken ct = default)
        {
            // Keyed on DeviceId, which is unique per tenant (UQ_Device_Tenant_DeviceId)
            // and a company maps to exactly one tenant, so there is no ambiguity.
            var rows = await _db.Devices.AsNoTracking()
                .Where(d => d.CompanyId == companyId
                            && d.DeviceName != null
                            && d.DeviceName != ""
                            && d.DeviceName != LegacyDeviceNamePlaceholder)
                .Select(d => new { d.DeviceId, d.DeviceName })
                .ToListAsync(ct);

            var map = new Dictionary<string, string>();
            foreach (var r in rows) map[r.DeviceId] = r.DeviceName!;
            return map;
        }

        /// <summary>Trims a supplied name; blank becomes null so it is never stored.</summary>
        private static string? NormalizeDeviceName(string? name)
        {
            var clean = name?.Trim();
            return string.IsNullOrEmpty(clean) ? null : clean;
        }

        /// <summary>
        /// Overwrites a registered device's name — but only with a real one. A
        /// blank/absent name means "the caller didn't say", not "clear it": an
        /// older client, or an ingress that carries no name header, must never
        /// wipe the label the operator set.
        ///
        /// 🚨 Nor with one another terminal carries. Login and every sync resend
        /// the terminal's local name, so without this a till named before the
        /// uniqueness check existed would push a duplicate straight past the
        /// check that <see cref="RenameDeviceAsync"/> enforces. Skipped silently:
        /// this runs inside login/sync, and a label must never fail either.
        /// </summary>
        private async Task ApplyDeviceNameAsync(DeviceRegistry device, string? deviceName, CancellationToken ct)
        {
            var clean = NormalizeDeviceName(deviceName);
            if (clean == null || device.DeviceName == clean) return;
            if (await IsNameHeldByAnotherDeviceAsync(device.TenantId, device.DeviceId, clean, ct)) return;
            device.DeviceName = clean;
        }

        /// <summary>
        /// Whether a terminal OTHER than <paramref name="deviceId"/> in the tenant
        /// carries <paramref name="cleanName"/>. Case-insensitive on every provider
        /// (UPPER on both sides) rather than trusting the SQL Server collation.
        /// A legacy <c>revoked</c> row is a tombstone and holds no name.
        /// </summary>
        private Task<bool> IsNameHeldByAnotherDeviceAsync(int tenantId, string deviceId, string cleanName, CancellationToken ct)
        {
            var upper = cleanName.ToUpperInvariant();
            return _db.Devices.AnyAsync(d => d.TenantId == tenantId
                                          && d.DeviceId != deviceId
                                          && d.Status != "revoked"
                                          && d.DeviceName != null
                                          && d.DeviceName.ToUpper() == upper, ct);
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
