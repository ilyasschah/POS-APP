namespace Api.Admin;

/// <summary>
/// The names that wire the admin portal's cookie authentication together. They
/// are spelled out once here because getting any one of them wrong locks the
/// portal out silently:
///
/// * <see cref="Scheme"/> must be named on the authorization policy
///   (<c>AddAuthenticationSchemes</c>). The API's DEFAULT scheme is JwtBearer, so
///   a policy that does not name this one authenticates a browser request against
///   the bearer handler, never sees the cookie, and challenges forever.
/// * <see cref="PolicyName"/> is attached to the /Admin folder by a Razor Pages
///   convention. That attachment is also what takes those pages out of the global
///   <c>FallbackPolicy</c> (RequireAuthenticatedUser over JwtBearer) — the fallback
///   only applies to endpoints carrying no authorization metadata of their own.
/// * <see cref="LoginPath"/> and <see cref="LogoutPath"/> must be reachable while
///   signed OUT, via <c>AllowAnonymousToPage</c>, or the login form itself demands
///   a login.
/// </summary>
public static class AdminPortalAuth
{
    public const string Scheme = "AdminPortalCookie";
    public const string PolicyName = "AdminPortal";
    public const string CookieName = "admin_portal_session";

    public const string LoginPath = "/admin/login";
    public const string LogoutPath = "/admin/logout";

    /// <summary>Razor page paths that stay anonymous, in Page-convention form.</summary>
    public const string LoginPage = "/Admin/Login";
    public const string LogoutPage = "/Admin/Logout";

    /// <summary>
    /// Claim carrying <c>AdminUser.MustChangePassword</c>, so the portal shell can
    /// render the default-credentials banner without a database hit per request.
    /// It is refreshed by re-issuing the cookie when the password changes.
    /// </summary>
    public const string MustChangePasswordClaim = "admin_must_change_password";

    /// <summary>Claim carrying the display name (falls back to the username).</summary>
    public const string DisplayNameClaim = "admin_display_name";

    /// <summary>
    /// Ordinary session lifetime, refreshed on activity (sliding). Long enough to
    /// work through a support session, short enough that an unattended back-office
    /// browser does not stay signed in overnight.
    /// </summary>
    public static readonly TimeSpan SessionLifetime = TimeSpan.FromHours(8);

    /// <summary>Lifetime when "Keep me signed in" is ticked; survives closing the browser.</summary>
    public static readonly TimeSpan RememberMeLifetime = TimeSpan.FromDays(14);
}
