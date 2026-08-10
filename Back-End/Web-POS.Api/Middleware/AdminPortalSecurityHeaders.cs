namespace Api.Middleware
{
    /// <summary>
    /// Applies hardening headers to every response under <c>/admin</c>.
    ///
    /// This is what remains of the old <c>AdminPortalGate</c>. The access control
    /// it used to perform — one shared <c>AdminPortal:AccessKey</c> supplied via
    /// <c>?key=</c> and remembered in a cookie — has been replaced by real per-user
    /// cookie authentication (see <see cref="Api.Admin.AdminPortalAuth"/>). The
    /// headers were never part of that gating and are still needed.
    ///
    /// ⚠️ Registered BEFORE UseAuthentication/UseAuthorization on purpose. The
    /// authorization middleware short-circuits an unauthenticated request with a
    /// 302 to the login page and never calls the rest of the pipeline, so a
    /// middleware placed after it (where the gate used to sit) would leave exactly
    /// the redirect and the challenge uncovered.
    /// </summary>
    public class AdminPortalSecurityHeaders
    {
        private readonly RequestDelegate _next;

        public AdminPortalSecurityHeaders(RequestDelegate next) => _next = next;

        public async Task Invoke(HttpContext context)
        {
            if (context.Request.Path.StartsWithSegments("/admin"))
                ApplySecurityHeaders(context);

            await _next(context);
        }

        private static void ApplySecurityHeaders(HttpContext context)
        {
            var headers = context.Response.Headers;
            headers["X-Content-Type-Options"] = "nosniff";
            headers["X-Frame-Options"] = "DENY";
            headers["Referrer-Policy"] = "no-referrer";
            // no-store matters specifically here: the portal renders every tenant's
            // billing and device records, and a cached page would persist them on
            // the disk of whatever machine the back office was opened from — plus
            // leave them on screen via Back after sign-out.
            headers["Cache-Control"] = "no-store, no-cache, must-revalidate";
            headers["Pragma"] = "no-cache";
        }
    }
}
