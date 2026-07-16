using Api.Master;
using Api.Master.Domain;
using Api.Master.Services;
using Api.Queries.CompanyQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Api.Pages.Admin.Subscriptions;

/// <summary>
/// Control-plane subscription management (Pillar 1/2). Lists every company with
/// its seats, active devices and days left, and lets the provider STOP or RESUME
/// billing, adjust days/seats, or start a subscription — all WITHOUT touching the
/// company's operational data. "Stop" flips BillingStatus to a stopped state; the
/// lease then issues as already-expired so the terminal blocks (reversibly).
/// </summary>
public class IndexModel : PageModel
{
    private readonly IMediator _mediator;
    private readonly MasterDbContext _master;
    private readonly ITenantProvisioningService _provisioning;

    public IndexModel(IMediator mediator, MasterDbContext master, ITenantProvisioningService provisioning)
    {
        _mediator = mediator;
        _master = master;
        _provisioning = provisioning;
    }

    public List<SubRow> Rows { get; private set; } = new();
    public bool MasterUnavailable { get; private set; }

    public class SubRow
    {
        public int CompanyId { get; set; }
        public string Name { get; set; } = "";
        public bool HasSubscription { get; set; }
        public bool IsActive { get; set; }
        public string BillingStatus { get; set; } = "—";
        public int SeatAllowance { get; set; }
        public int ActiveDevices { get; set; }
        public DateTime? PeriodEnd { get; set; }
        public int? DaysLeft { get; set; }
    }

    public async Task OnGetAsync() => await LoadAsync();

    private async Task LoadAsync()
    {
        var companies = await _mediator.Send(new GetAllCompaniesQuery());
        Rows = companies
            .OrderBy(c => c.Name)
            .Select(c => new SubRow { CompanyId = c.Id, Name = c.Name })
            .ToList();

        // Control-plane joins in ONE pass (non-fatal — a Master-DB hiccup just
        // shows the companies with no subscription detail + a banner).
        try
        {
            var tenants = await _master.Tenants.AsNoTracking().ToListAsync();
            var subs = await _master.Subscriptions.AsNoTracking().ToListAsync();
            var deviceCounts = await _master.Devices
                .Where(d => d.Status == "active")
                .GroupBy(d => d.TenantId)
                .Select(g => new { TenantId = g.Key, Count = g.Count() })
                .ToListAsync();

            var devicesByTenant = deviceCounts.ToDictionary(x => x.TenantId, x => x.Count);
            var tenantByCompany = tenants.ToDictionary(t => t.CompanyId);
            var subByTenant = subs.ToDictionary(s => s.TenantId);

            var now = DateTime.UtcNow;
            foreach (var row in Rows)
            {
                if (!tenantByCompany.TryGetValue(row.CompanyId, out var tenant)) continue;
                if (!subByTenant.TryGetValue(tenant.Id, out var sub)) continue;

                row.HasSubscription = true;
                row.BillingStatus = sub.BillingStatus ?? "—";
                row.IsActive = !IsStopped(sub.BillingStatus);
                row.SeatAllowance = sub.SeatAllowance;
                row.ActiveDevices = devicesByTenant.GetValueOrDefault(tenant.Id);
                row.PeriodEnd = sub.CurrentPeriodEnd;
                if (sub.CurrentPeriodEnd != null)
                    row.DaysLeft = (int)Math.Ceiling(
                        (sub.CurrentPeriodEnd.Value.ToUniversalTime() - now).TotalDays);
            }
        }
        catch
        {
            MasterUnavailable = true;
        }
    }

    public async Task<IActionResult> OnPostToggleAsync(int companyId, bool turnOn)
    {
        try
        {
            var sub = await GetSubAsync(companyId);
            if (sub == null)
            {
                TempData["Error"] = "This company has no subscription yet — start one first.";
                return RedirectToPage();
            }

            sub.BillingStatus = turnOn ? SubscriptionStatusActive : SubscriptionStatusStopped;
            // Resuming with no time left would still read as expired, so a "resume"
            // wouldn't actually let them work. Give a fresh period when it's empty.
            if (turnOn &&
                (sub.CurrentPeriodEnd == null || sub.CurrentPeriodEnd.Value.ToUniversalTime() <= DateTime.UtcNow))
                sub.CurrentPeriodEnd = DateTime.UtcNow.AddDays(30);
            sub.LastModified = DateTime.UtcNow;
            await _master.SaveChangesAsync();

            TempData["Success"] = turnOn
                ? "Subscription resumed — the terminal is re-licensed on its next lease refresh."
                : "Subscription stopped — the terminal blocks on its next lease refresh. No company data was deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
        }
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostSetDaysAsync(int companyId, int days)
    {
        if (days < 0) days = 0;
        try
        {
            var sub = await GetSubAsync(companyId);
            if (sub == null)
            {
                TempData["Error"] = "This company has no subscription yet — start one first.";
                return RedirectToPage();
            }
            sub.CurrentPeriodEnd = DateTime.UtcNow.AddDays(days);
            sub.LastModified = DateTime.UtcNow;
            await _master.SaveChangesAsync();
            TempData["Success"] = $"Subscription now runs {days} day(s) from today.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
        }
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostSetSeatsAsync(int companyId, int seats)
    {
        if (seats < 1) seats = 1;
        try
        {
            var sub = await GetSubAsync(companyId);
            if (sub == null)
            {
                TempData["Error"] = "This company has no subscription yet — start one first.";
                return RedirectToPage();
            }
            sub.SeatAllowance = seats;
            sub.LastModified = DateTime.UtcNow;
            await _master.SaveChangesAsync();
            TempData["Success"] = $"Seat allowance set to {seats} terminal(s).";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Update failed: {ex.Message}";
        }
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostStartAsync(int companyId, string? name, int seats, int days)
    {
        if (seats < 1) seats = 1;
        if (days < 1) days = 30;
        try
        {
            await _provisioning.ProvisionTenantAsync(
                companyId,
                string.IsNullOrWhiteSpace(name) ? $"Company {companyId}" : name!,
                seats,
                days);
            TempData["Success"] = "Subscription started.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Start failed: {ex.Message}";
        }
        return RedirectToPage();
    }

    private async Task<Subscription?> GetSubAsync(int companyId)
    {
        var tenant = await _master.Tenants.FirstOrDefaultAsync(t => t.CompanyId == companyId);
        if (tenant == null) return null;
        return await _master.Subscriptions.FirstOrDefaultAsync(s => s.TenantId == tenant.Id);
    }

    // Kept in sync with LeaseService._stoppedStatuses (which drives the lease).
    private const string SubscriptionStatusActive = "active";
    private const string SubscriptionStatusStopped = "canceled";
    private static readonly HashSet<string> _stopped =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "canceled", "cancelled", "paused", "suspended", "inactive",
        };
    private static bool IsStopped(string? status) =>
        status != null && _stopped.Contains(status.Trim());
}
