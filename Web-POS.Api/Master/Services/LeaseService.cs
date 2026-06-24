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
            var periodEnd = sub?.CurrentPeriodEnd ?? now.AddDays(_fallbackTrialDays);
            var validUntil = periodEnd.AddDays(_graceDays).ToUniversalTime();

            var claims = new List<Claim>
            {
                new("companyId",     companyId.ToString()),
                new("tenantId",      (tenant?.Id ?? 0).ToString()),
                new("seatAllowance", (sub?.SeatAllowance ?? 0).ToString()),
                new("billingStatus", sub?.BillingStatus ?? "none"),
                new("validUntil",    validUntil.ToString("o")),
                new("issuedAt",      now.ToString("o")),
            };

            var creds = new SigningCredentials(_keys.SigningKey, SecurityAlgorithms.RsaSha256);
            var jwt = new JwtSecurityToken(
                claims: claims,
                notBefore: now,
                expires: validUntil,
                signingCredentials: creds);

            return new JwtSecurityTokenHandler().WriteToken(jwt);
        }
    }
}
