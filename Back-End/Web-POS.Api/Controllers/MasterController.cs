using Api.Master;
using Api.Master.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace Api.Controllers
{
    /// <summary>
    /// Admin/control-plane endpoints over the Master SaaS database (Pillar 1).
    /// Read + manual provisioning for now; seat enforcement (Pillar 4) and Stripe
    /// webhooks (Pillar 1 billing) attach to the same context in later phases.
    /// </summary>
    [Route("api/[controller]")]
    [ApiController]
    public class MasterController(MasterDbContext db, ITenantProvisioningService provisioning, LeaseKeyService leaseKeys, LeaseService leaseService, ICloneAuditService cloneAudit) : ControllerBase
    {
        /// <summary>Pillar 5 — flagged clone / duplicate transactions for a tenant.</summary>
        [HttpGet("[action]")]
        public async Task<IActionResult> CloneAlerts([FromQuery] int companyId)
            => Ok(await cloneAudit.GetAlertsAsync(companyId));

        /// <summary>Public key the app uses to verify offline subscription leases (Pillar 2).</summary>
        // Licensing bootstrap: the app may fetch this around token-refresh boundaries,
        // and it is a public key — anonymous by design.
        [AllowAnonymous]
        [HttpGet("[action]")]
        public IActionResult LeasePublicKey()
            => Ok(new { publicKeyPem = leaseKeys.PublicKeyPem });

        /// <summary>
        /// Re-issues a fresh signed lease for a company (Pillar 2). The app calls
        /// this on every sync so the offline `validUntil` window keeps sliding
        /// forward while the terminal is online — and so a renewed subscription
        /// takes effect without a re-login. The lease's `issuedAt` doubles as the
        /// trusted server clock the app pins for anti-rollback.
        /// </summary>
        // Licensing bootstrap. Its security is the RS256 signature (Pillar 2), not
        // transport auth — the app must be able to (re)fetch it while its token is
        // mid-refresh, so it is anonymous by design.
        [AllowAnonymous]
        [HttpGet("[action]")]
        public async Task<IActionResult> Lease([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("companyId is required");
            return Ok(new { lease = await leaseService.IssueLeaseAsync(companyId) });
        }

        [HttpGet("[action]")]
        public async Task<IActionResult> Tenants()
            => Ok(await db.Tenants.AsNoTracking().OrderBy(t => t.Id).ToListAsync());

        [HttpGet("[action]")]
        public async Task<IActionResult> Subscriptions()
            => Ok(await db.Subscriptions.AsNoTracking().OrderBy(s => s.TenantId).ToListAsync());

        [HttpGet("[action]")]
        public async Task<IActionResult> Devices([FromQuery] int? tenantId)
            => Ok(await db.Devices.AsNoTracking()
                    .Where(d => tenantId == null || d.TenantId == tenantId)
                    .OrderBy(d => d.TenantId).ToListAsync());

        /// <summary>Manually provision (or no-op if it exists) a tenant + default subscription.</summary>
        [HttpPost("[action]")]
        public async Task<IActionResult> Provision([FromQuery] int companyId, [FromQuery] string name, [FromQuery] int seats = 1)
        {
            if (companyId <= 0) return BadRequest("companyId is required");
            var tenant = await provisioning.ProvisionTenantAsync(companyId, name, seats);
            return Ok(tenant);
        }

        /// <summary>Seat-cap check primitive (what the sync ingress will call in Pillar 4).</summary>
        [HttpPost("[action]")]
        public async Task<IActionResult> CheckDevice([FromQuery] int companyId, [FromQuery] string deviceId, [FromQuery] string? deviceName)
        {
            var result = await provisioning.RegisterOrValidateDeviceAsync(companyId, deviceId, deviceName);
            return result.Allowed ? Ok(result) : StatusCode(StatusCodes.Status403Forbidden, result);
        }

        /// <summary>
        /// Renames this terminal in the registry so the admin device list shows
        /// "POS1" instead of a UUID. CompanyId comes from the caller's token, so a
        /// device can only rename within its own tenant. Seat state is untouched —
        /// this is a label change, never a registration.
        /// </summary>
        [Authorize]
        [HttpPost("[action]")]
        public async Task<IActionResult> RenameDevice([FromQuery] string deviceId, [FromQuery] string deviceName)
        {
            if (string.IsNullOrWhiteSpace(deviceId))
                return BadRequest(new { message = "deviceId is required." });
            if (string.IsNullOrWhiteSpace(deviceName))
                return BadRequest(new { message = "deviceName is required." });
            if (!int.TryParse(User.FindFirstValue("companyId"), out var companyId) || companyId <= 0)
                return Unauthorized();

            var renamed = await provisioning.RenameDeviceAsync(companyId, deviceId, deviceName);
            return Ok(new { success = renamed });
        }

        /// <summary>
        /// Releases this device's seat on sign-out (Pillar 4). CompanyId comes from
        /// the caller's token so a device can only release itself within its own
        /// tenant; the device re-activates automatically on its next login/sync.
        /// </summary>
        [Authorize]
        [HttpPost("[action]")]
        public async Task<IActionResult> ReleaseDevice([FromQuery] string deviceId)
        {
            if (string.IsNullOrWhiteSpace(deviceId))
                return BadRequest(new { message = "deviceId is required." });
            if (!int.TryParse(User.FindFirstValue("companyId"), out var companyId) || companyId <= 0)
                return Unauthorized();

            await provisioning.ReleaseDeviceAsync(companyId, deviceId);
            return Ok(new { success = true });
        }
    }
}
