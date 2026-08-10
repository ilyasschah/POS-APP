using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Api.Admin;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Api.Pages.Admin;

/// <summary>
/// The admin portal's login form. Reachable while signed out because
/// Program.cs marks it <c>AllowAnonymousToPage</c> — without that it would sit
/// under the folder's own authorize convention and demand a login to show the
/// login form.
/// </summary>
public class LoginModel : PageModel
{
    /// <summary>
    /// One message for every failure. Naming the reason ("no such user" vs "wrong
    /// password" vs "account disabled") turns the form into a username oracle;
    /// AdminUserService equalises the response TIME for the same reason.
    /// </summary>
    private const string GenericFailure = "Incorrect username or password.";

    /// <summary>
    /// Deliberately distinguishable from <see cref="GenericFailure"/>. Accounts
    /// live in the Master DB, so an unreachable control plane makes every sign-in
    /// fail — and rendering that as "incorrect password" sends the operator off to
    /// reset a password that was never wrong. This repo has already lost a session
    /// to two unrelated conditions sharing one message.
    /// It reveals nothing: a database being down is not a fact about any account.
    /// </summary>
    private const string ControlPlaneUnavailable =
        "The admin database is unreachable, so sign-in cannot be checked right now. " +
        "This is not a problem with your password — see the API log for details.";

    private readonly AdminUserService _users;
    private readonly ILogger<LoginModel> _logger;

    public LoginModel(AdminUserService users, ILogger<LoginModel> logger)
    {
        _users = users;
        _logger = logger;
    }

    [BindProperty] public InputModel Input { get; set; } = new();

    public string? ErrorMessage { get; private set; }

    public class InputModel
    {
        [Required] public string? Username { get; set; }
        [Required] public string? Password { get; set; }
        public bool RememberMe { get; set; }
    }

    public async Task<IActionResult> OnGetAsync(string? returnUrl = null)
    {
        // Landing on the login page is how you switch accounts, so drop whatever
        // session is already here rather than bouncing straight back into it.
        await HttpContext.SignOutAsync(AdminPortalAuth.Scheme);
        ViewData["ReturnUrl"] = SafeReturnUrl(returnUrl);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(string? returnUrl = null)
    {
        var target = SafeReturnUrl(returnUrl);
        ViewData["ReturnUrl"] = target;

        if (!ModelState.IsValid)
        {
            ErrorMessage = GenericFailure;
            return Page();
        }

        Master.Domain.AdminUser? user;
        try
        {
            user = await _users.ValidateCredentialsAsync(Input.Username, Input.Password);
        }
        catch (Exception ex)
        {
            // Narrow by scope rather than by exception type: ValidateCredentialsAsync
            // makes no credential decision by throwing — a bad password returns null
            // and a malformed stored hash is absorbed inside — so anything arriving
            // here is the database or the connection, never the operator.
            _logger.LogError(ex, "Admin portal sign-in could not reach the Master database.");
            ErrorMessage = ControlPlaneUnavailable;
            return Page();
        }

        if (user is null)
        {
            // Logged without the password, and with the attempted username only —
            // the log is not a place to reproduce a credential.
            _logger.LogWarning(
                "Admin portal sign-in failed for username '{username}' from {ip}.",
                Input.Username, HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown");
            ErrorMessage = GenericFailure;
            return Page();
        }

        await _users.RecordLoginAsync(user);

        var identity = new ClaimsIdentity(
            new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Username),
                new Claim(AdminPortalAuth.DisplayNameClaim,
                    string.IsNullOrWhiteSpace(user.DisplayName) ? user.Username : user.DisplayName),
                new Claim(AdminPortalAuth.MustChangePasswordClaim,
                    user.MustChangePassword ? "true" : "false"),
            },
            AdminPortalAuth.Scheme);

        var properties = new AuthenticationProperties
        {
            // Persistent survives closing the browser; otherwise the cookie dies
            // with the session and the 8h expiry is just the upper bound.
            IsPersistent = Input.RememberMe,
            ExpiresUtc = DateTimeOffset.UtcNow +
                (Input.RememberMe
                    ? AdminPortalAuth.RememberMeLifetime
                    : AdminPortalAuth.SessionLifetime),
        };

        await HttpContext.SignInAsync(
            AdminPortalAuth.Scheme, new ClaimsPrincipal(identity), properties);

        _logger.LogInformation(
            "Admin portal sign-in: '{username}' (id {id}).", user.Username, user.Id);

        return LocalRedirect(target);
    }

    /// <summary>
    /// Only same-site paths are followed. An unchecked returnUrl makes the login
    /// page an open redirect, which is exactly the shape a phishing link wants.
    /// </summary>
    private string SafeReturnUrl(string? returnUrl) =>
        !string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl)
            ? returnUrl
            : Url.Page("/Admin/Companies/Index")!;
}
