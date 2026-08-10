using Api.Admin;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Api.Pages.Admin;

/// <summary>
/// Sign-out. Anonymous on purpose: signing out of an already-expired session must
/// land on the login page, not be challenged for a login first.
/// This page renders nothing — both handlers redirect.
/// </summary>
public class LogoutModel : PageModel
{
    private readonly ILogger<LogoutModel> _logger;

    public LogoutModel(ILogger<LogoutModel> logger) => _logger = logger;

    /// <summary>
    /// A GET here means a stray link or a bookmark, never the Sign out button
    /// (which posts, with an antiforgery token — a GET sign-out is CSRF-able and
    /// can be triggered by any image tag on any page).
    /// </summary>
    public IActionResult OnGet() => RedirectToPage(AdminPortalAuth.LoginPage);

    public async Task<IActionResult> OnPostAsync()
    {
        var username = User.Identity?.Name;
        await HttpContext.SignOutAsync(AdminPortalAuth.Scheme);

        if (!string.IsNullOrEmpty(username))
            _logger.LogInformation("Admin portal sign-out: '{username}'.", username);

        return RedirectToPage(AdminPortalAuth.LoginPage);
    }
}
