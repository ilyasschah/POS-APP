using Api.Commands.UserCommands.Add;
using Api.Commands.UserCommands.Delete;
using Api.Commands.UserCommands.Update;
using Api.Master;
using Api.Master.Domain;
using Api.Models;
using Api.Queries.CompanyQuery;
using Api.Queries.UserQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Api.Pages.Admin.Companies;

public class DetailsModel : PageModel
{
    private readonly IMediator _mediator;
    private readonly MasterDbContext _master;
    public DetailsModel(IMediator mediator, MasterDbContext master)
    {
        _mediator = mediator;
        _master = master;
    }

    public CompanyDto? Company { get; private set; }
    public List<UserDto> Users { get; private set; } = new();

    // Pillar 1/4 control-plane stats for this company.
    public bool HasTenant { get; private set; }
    public int RegisteredDevices { get; private set; }
    public int SeatAllowance { get; private set; }
    public string BillingStatus { get; private set; } = "—";
    public DateTime? SubscriptionEnd { get; private set; }
    public int? SubscriptionDaysLeft { get; private set; }

    // Pillar 5 — clone / duplication audit.
    public int CloneAlertCount { get; private set; }
    public List<TransactionAudit> CloneAlerts { get; private set; } = new();

    [BindProperty] public NewUserModel NewUser { get; set; } = new();

    public class NewUserModel
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public string? Email { get; set; }
        public int AccessLevel { get; set; } = 1;
    }

    public async Task<IActionResult> OnGetAsync(int id)
    {
        if (!await LoadAsync(id)) return RedirectToPage("Index");
        return Page();
    }

    public async Task<IActionResult> OnPostAddUserAsync(int id)
    {
        if (string.IsNullOrWhiteSpace(NewUser.Username) || string.IsNullOrWhiteSpace(NewUser.Password))
        {
            TempData["Error"] = "Username and password are required.";
            return RedirectToPage(new { id });
        }
        try
        {
            await _mediator.Send(new AddUserCommand(new CreateUserRequest
            {
                Username = NewUser.Username,
                Password = NewUser.Password,
                FirstName = NewUser.FirstName,
                LastName = NewUser.LastName,
                Email = NewUser.Email,
                AccessLevel = NewUser.AccessLevel,
                IsEnabled = true,
            }, id));
            TempData["Success"] = $"User '{NewUser.Username}' created.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Add user failed: {ex.Message}";
        }
        return RedirectToPage(new { id });
    }

    public async Task<IActionResult> OnPostDeleteUserAsync(int id, int userId)
    {
        try
        {
            await _mediator.Send(new DeleteUserCommand(userId, id));
            TempData["Success"] = "User deleted.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Delete user failed: {ex.Message}";
        }
        return RedirectToPage(new { id });
    }

    public async Task<IActionResult> OnPostResetPasswordAsync(int id, int userId, string newPassword)
    {
        if (string.IsNullOrWhiteSpace(newPassword))
        {
            TempData["Error"] = "New password cannot be empty.";
            return RedirectToPage(new { id });
        }
        try
        {
            await _mediator.Send(new AdminResetPasswordCommand(
                new AdminResetPasswordRequest { UserId = userId, NewPassword = newPassword }, id));
            TempData["Success"] = "Password reset.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Reset failed: {ex.Message}";
        }
        return RedirectToPage(new { id });
    }

    private async Task<bool> LoadAsync(int id)
    {
        Company = await _mediator.Send(new GetCompanyByIdQuery(id));
        if (Company == null)
        {
            TempData["Error"] = $"Company {id} not found.";
            return false;
        }
        Users = await _mediator.Send(new GetAllUsersQuery { CompanyId = id, IncludeDisabled = true });

        // Master-DB control-plane stats (non-fatal — a Master-DB hiccup or an
        // unprovisioned company just shows "no tenant").
        try
        {
            var tenant = await _master.Tenants.AsNoTracking().FirstOrDefaultAsync(t => t.CompanyId == id);
            if (tenant != null)
            {
                HasTenant = true;
                RegisteredDevices = await _master.Devices
                    .CountAsync(d => d.TenantId == tenant.Id && d.Status == "active");
                var sub = await _master.Subscriptions.AsNoTracking()
                    .FirstOrDefaultAsync(s => s.TenantId == tenant.Id);
                if (sub != null)
                {
                    SeatAllowance = sub.SeatAllowance;
                    BillingStatus = sub.BillingStatus;
                    SubscriptionEnd = sub.CurrentPeriodEnd;
                    if (sub.CurrentPeriodEnd != null)
                        SubscriptionDaysLeft = (int)Math.Ceiling(
                            (sub.CurrentPeriodEnd.Value.ToUniversalTime() - DateTime.UtcNow).TotalDays);
                }
            }

            // Pillar 5 — flagged clone / duplicate transactions for this company.
            CloneAlertCount = await _master.TransactionAudits.AsNoTracking()
                .CountAsync(a => a.CompanyId == id && a.IsFlagged);
            CloneAlerts = await _master.TransactionAudits.AsNoTracking()
                .Where(a => a.CompanyId == id && a.IsFlagged)
                .OrderByDescending(a => a.LastSeenUtc)
                .Take(10)
                .ToListAsync();
        }
        catch { /* control plane unavailable — leave stats blank */ }

        return true;
    }
}
