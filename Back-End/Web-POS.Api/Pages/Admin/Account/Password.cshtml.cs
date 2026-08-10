using System.Security.Claims;
using Api.Admin;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Api.Pages.Admin.Account;

/// <summary>
/// Lets the signed-in operator change their own password. This is the exit from
/// the seeded <c>Admin</c> / <c>Admin@123</c> account, which is the only reason
/// <see cref="Api.Master.Domain.AdminUser.MustChangePassword"/> exists.
/// </summary>
public class PasswordModel : PageModel
{
    public const int MinimumLength = 10;

    private readonly AdminUserService _users;
    private readonly ILogger<PasswordModel> _logger;

    public PasswordModel(AdminUserService users, ILogger<PasswordModel> logger)
    {
        _users = users;
        _logger = logger;
    }

    [BindProperty] public InputModel Input { get; set; } = new();

    public string Username => User.Identity?.Name ?? "unknown";
    public string? ErrorMessage { get; private set; }

    public class InputModel
    {
        public string? CurrentPassword { get; set; }
        public string? NewPassword { get; set; }
        public string? ConfirmPassword { get; set; }
    }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync()
    {
        var user = await _users.FindByIdAsync(CurrentUserId());
        if (user is null)
        {
            // The account was deleted out from under a live cookie. Nothing here can
            // succeed, and the session is meaningless — end it.
            await HttpContext.SignOutAsync(AdminPortalAuth.Scheme);
            return RedirectToPage(AdminPortalAuth.LoginPage);
        }

        var newPassword = Input.NewPassword ?? string.Empty;

        if (newPassword.Length < MinimumLength)
            return Fail($"The new password must be at least {MinimumLength} characters.");

        if (!string.Equals(newPassword, Input.ConfirmPassword, StringComparison.Ordinal))
            return Fail("The new password and its confirmation do not match.");

        // Blocked explicitly rather than left to the length rule: the whole point of
        // this page is getting off the published default, and it is 9 characters —
        // so the length check happens to catch it today and would stop doing so if
        // MinimumLength were ever lowered.
        if (string.Equals(newPassword, AdminUserSeeder.DefaultPassword, StringComparison.Ordinal))
            return Fail("That is the default password shipped with the software. Choose a different one.");

        if (!await _users.ChangePasswordAsync(user, Input.CurrentPassword, newPassword))
            return Fail("Your current password is not correct.");

        // The MustChangePassword claim is baked into the cookie, so the banner would
        // keep nagging until the next sign-in unless the ticket is re-issued here.
        await RefreshSessionAsync(user.Id, user.Username, user.DisplayName);

        _logger.LogInformation("Admin portal password changed for '{username}'.", user.Username);
        TempData["Success"] = "Your password has been changed.";
        return RedirectToPage("/Admin/Companies/Index");
    }

    private IActionResult Fail(string message)
    {
        ErrorMessage = message;
        return Page();
    }

    private int CurrentUserId() =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0;

    private async Task RefreshSessionAsync(int id, string username, string? displayName)
    {
        var identity = new ClaimsIdentity(
            new[]
            {
                new Claim(ClaimTypes.NameIdentifier, id.ToString()),
                new Claim(ClaimTypes.Name, username),
                new Claim(AdminPortalAuth.DisplayNameClaim,
                    string.IsNullOrWhiteSpace(displayName) ? username : displayName),
                new Claim(AdminPortalAuth.MustChangePasswordClaim, "false"),
            },
            AdminPortalAuth.Scheme);

        await HttpContext.SignInAsync(
            AdminPortalAuth.Scheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties
            {
                IsPersistent = false,
                ExpiresUtc = DateTimeOffset.UtcNow + AdminPortalAuth.SessionLifetime,
            });
    }
}
