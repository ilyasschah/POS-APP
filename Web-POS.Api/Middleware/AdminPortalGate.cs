namespace Api.Middleware
{
    /// <summary>
    /// Lightweight shared-secret gate for the admin portal (everything under
    /// <c>/admin</c>). There is no login form — a single key configured at
    /// <c>AdminPortal:AccessKey</c> must be supplied once via <c>?key=</c>, which
    /// is then stored in a cookie for the session. Requests without a matching
    /// key get a 403. This keeps the destructive admin surface (delete company,
    /// reset passwords) off the open network without a full auth system.
    /// </summary>
    public class AdminPortalGate
    {
        private const string CookieName = "admin_portal_key";
        private readonly RequestDelegate _next;
        private readonly string _key;

        public AdminPortalGate(RequestDelegate next, IConfiguration config)
        {
            _next = next;
            _key = config["AdminPortal:AccessKey"] ?? string.Empty;
        }

        public async Task Invoke(HttpContext context)
        {
            var path = context.Request.Path;
            if (!path.StartsWithSegments("/admin"))
            {
                await _next(context);
                return;
            }

            // Misconfiguration guard: an empty key would otherwise allow everyone.
            if (string.IsNullOrWhiteSpace(_key))
            {
                context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
                await context.Response.WriteAsync(
                    "Admin portal disabled: set AdminPortal:AccessKey in configuration.");
                return;
            }

            // Already authorised for this session.
            if (context.Request.Cookies.TryGetValue(CookieName, out var cookieKey) &&
                cookieKey == _key)
            {
                await _next(context);
                return;
            }

            // First entry via ?key=... — persist it and redirect to a clean URL.
            if (context.Request.Query.TryGetValue("key", out var queryKey) &&
                queryKey == _key)
            {
                context.Response.Cookies.Append(CookieName, _key, new CookieOptions
                {
                    HttpOnly = true,
                    SameSite = SameSiteMode.Lax,
                    Secure = context.Request.IsHttps,
                });
                context.Response.Redirect(path + context.Request.QueryString.Value?
                    .Replace($"key={queryKey}", string.Empty).TrimEnd('?', '&'));
                return;
            }

            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsync(
                "Forbidden. Append ?key=<your AdminPortal:AccessKey> to the URL once to enter the admin portal.");
        }
    }
}
