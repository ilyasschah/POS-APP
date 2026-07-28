using System.Security.Cryptography;
using System.Text;

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
        private readonly byte[] _keyBytes;

        public AdminPortalGate(RequestDelegate next, IConfiguration config)
        {
            _next = next;
            _key = config["AdminPortal:AccessKey"] ?? string.Empty;
            _keyBytes = Encoding.UTF8.GetBytes(_key);
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

            // The portal is a destructive back-office surface — keep it out of
            // caches, search indexes, and framed pages regardless of the outcome
            // below. Set before any early return so the 403/503 bodies carry them too.
            ApplySecurityHeaders(context);

            // Already authorised for this session.
            if (context.Request.Cookies.TryGetValue(CookieName, out var cookieKey) &&
                FixedTimeEquals(cookieKey))
            {
                await _next(context);
                return;
            }

            // First entry via ?key=... — persist it and redirect to a clean URL.
            if (context.Request.Query.TryGetValue("key", out var queryKey) &&
                FixedTimeEquals(queryKey))
            {
                context.Response.Cookies.Append(CookieName, _key, new CookieOptions
                {
                    HttpOnly = true,
                    SameSite = SameSiteMode.Lax,
                    Secure = context.Request.IsHttps,
                });

                // Rebuild the query string without the key rather than string-replacing
                // it: the previous Replace left a stray separator for multi-parameter
                // URLs (?a=1&key=K -> ?a=1&) and could corrupt a value that happened to
                // contain the same text.
                var remaining = context.Request.Query
                    .Where(kv => kv.Key != "key")
                    .SelectMany(kv => kv.Value.Select(v => (kv.Key, Value: v)))
                    .ToList();
                var queryString = QueryString.Empty;
                foreach (var (name, value) in remaining)
                    queryString = queryString.Add(name, value ?? string.Empty);

                context.Response.Redirect(path + queryString.ToUriComponent());
                return;
            }

            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsync(
                "Forbidden. Append ?key=<your AdminPortal:AccessKey> to the URL once to enter the admin portal.");
        }

        /// <summary>
        /// Constant-time comparison. An ordinary <c>==</c> on strings short-circuits at
        /// the first differing byte, which leaks the length of the matching prefix to
        /// anyone able to time responses — enough to recover the key character by
        /// character over many requests. <see cref="CryptographicOperations.FixedTimeEquals"/>
        /// always inspects the full buffer.
        /// </summary>
        private bool FixedTimeEquals(string? candidate)
        {
            if (candidate is null) return false;
            var candidateBytes = Encoding.UTF8.GetBytes(candidate);
            // FixedTimeEquals requires equal lengths; comparing the lengths first is
            // safe because the key's length is not the secret its characters are.
            if (candidateBytes.Length != _keyBytes.Length) return false;
            return CryptographicOperations.FixedTimeEquals(candidateBytes, _keyBytes);
        }

        private static void ApplySecurityHeaders(HttpContext context)
        {
            var headers = context.Response.Headers;
            headers["X-Content-Type-Options"] = "nosniff";
            headers["X-Frame-Options"] = "DENY";
            headers["Referrer-Policy"] = "no-referrer";
            // no-store matters specifically here: the access key travels in the URL on
            // first entry, and a cached admin page would persist tenant data on disk.
            headers["Cache-Control"] = "no-store, no-cache, must-revalidate";
            headers["Pragma"] = "no-cache";
        }
    }
}
