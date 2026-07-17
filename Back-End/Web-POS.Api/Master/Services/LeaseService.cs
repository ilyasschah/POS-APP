using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Api.Master.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace Api.Master.Services
{
    /// <summary>
    /// Issues a signed offline subscription lease (Pillar 2) for a company. The
    /// lease's <c>validUntil</c> = the tenant's subscription period end + a grace
    /// window; when there is no provisioned subscription it falls back to a trial
    /// window so a not-yet-provisioned company is never locked out. Resilient: a
    /// Master-DB hiccup yields a fallback lease rather than failing login.
    /// </summary>
    public class LeaseService
    {
        private readonly MasterDbContext _master;
        private readonly LeaseKeyService _keys;
        private readonly int _graceDays;
        private readonly int _fallbackTrialDays;

        public LeaseService(MasterDbContext master, LeaseKeyService keys, IConfiguration config)
        {
            _master = master;
            _keys = keys;
            _graceDays = config.GetValue<int?>("Lease:GraceDays") ?? 3;
            _fallbackTrialDays = config.GetValue<int?>("Lease:FallbackTrialDays") ?? 30;
        }

        public async Task<string> IssueLeaseAsync(int companyId)
        {
            Tenant? tenant = null;
            Subscription? sub = null;
            try
            {
                tenant = await _master.Tenants.AsNoTracking()
                    .FirstOrDefaultAsync(t => t.CompanyId == companyId);
                if (tenant != null)
                    sub = await _master.Subscriptions.AsNoTracking()
                        .FirstOrDefaultAsync(s => s.TenantId == tenant.Id);
            }
            catch
            {
                // Control plane unavailable — issue a short fallback lease below.
            }

            var now = DateTime.UtcNow;

            DateTime validUntil;
            string billingStatus;
            // The subscription's own period end, before the grace window is added.
            // The device enforces `validUntil` (end + grace) but shows this, so the
            // renewal date the customer sees matches what they are billed for.
            DateTime? periodEnd = null;
            if (sub != null)
            {
                var status = (sub.BillingStatus ?? "active").Trim().ToLowerInvariant();
                if (IsStopped(status))
                {
                    // Subscription switched OFF by the provider (admin Subscriptions
                    // page) WITHOUT deleting any company data. Issue an already-expired
                    // lease so the terminal blocks with "contact your service provider".
                    // Fully reversible: flipping it back to active + a future period end
                    // re-licenses the device on its next lease refresh.
                    validUntil = now;
                    billingStatus = status;
                }
                else
                {
                    // Normal path: honour the subscription's period end (+ grace).
                    periodEnd = (sub.CurrentPeriodEnd ?? now).ToUniversalTime();
                    validUntil = periodEnd.Value.AddDays(_graceDays);
                    billingStatus = sub.BillingStatus ?? "active";
                }
            }
            else if (tenant == null)
            {
                // Never provisioned (fresh company, or a Master-DB hiccup): a short
                // trial so a brand-new company is never locked out before its tenant
                // is provisioned.
                validUntil = now.AddDays(_fallbackTrialDays + _graceDays).ToUniversalTime();
                billingStatus = "none";
            }
            else
            {
                // Tenant exists but its subscription was deleted → REVOKED. Issue an
                // already-expired lease and do NOT re-grant a trial — otherwise a
                // cancelled account would silently re-license itself on every sync.
                validUntil = now;
                billingStatus = "revoked";
            }

            var claims = new List<Claim>
            {
                new("companyId",     companyId.ToString()),
                new("tenantId",      (tenant?.Id ?? 0).ToString()),
                new("seatAllowance", (sub?.SeatAllowance ?? 0).ToString()),
                new("billingStatus", billingStatus),
                new("validUntil",    validUntil.ToString("o")),
                new("issuedAt",      now.ToString("o")),
            };

            // Display-only claims for the terminal's Subscription tab. Omitted rather
            // than zero-valued when unknown, so the device shows "—" instead of a
            // date it would otherwise have to invent.
            if (tenant != null)
                claims.Add(new Claim("startedAt", tenant.CreatedAt.ToUniversalTime().ToString("o")));
            if (periodEnd != null)
                claims.Add(new Claim("periodEnd", periodEnd.Value.ToString("o")));

            var creds = new SigningCredentials(_keys.SigningKey, SecurityAlgorithms.RsaSha256);
            var jwt = new JwtSecurityToken(
                claims: claims,
                // nbf a minute back so a 'revoked' lease (validUntil == now) still
                // has expires > notBefore and constructs cleanly. The device enforces
                // the validUntil CLAIM, not the JWT exp.
                notBefore: now.AddMinutes(-1),
                expires: validUntil > now ? validUntil : now.AddMinutes(1),
                signingCredentials: creds);

            return new JwtSecurityTokenHandler().WriteToken(jwt);
        }

        /// <summary>Billing statuses that mean the subscription is switched OFF
        /// (company data preserved, terminal blocked). Kept in sync with the admin
        /// Subscriptions page toggle.</summary>
        private static readonly HashSet<string> _stoppedStatuses =
            new(StringComparer.OrdinalIgnoreCase)
            {
                "canceled", "cancelled", "paused", "suspended", "inactive",
            };

        private static bool IsStopped(string? status) =>
            status != null && _stoppedStatuses.Contains(status.Trim());
    }
}
