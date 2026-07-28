using System.Net;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Api.Middleware
{
    /// <summary>
    /// Translates expected business-rule failures into the structured JSON error
    /// contract <c>{ success: false, message }</c> with an appropriate status
    /// code, instead of letting them bubble up as raw 500s.
    ///
    /// Per CLAUDE.md: "Business logic failures (like 'Out of Stock') must return a
    /// 400 Bad Request with a structured JSON payload. Do not throw unhandled 500
    /// exceptions for business logic." This middleware enforces that globally so
    /// every command/service can just <c>throw new InvalidOperationException(...)</c>
    /// and the client receives a clean, parseable error (which the offline-first
    /// sync uses to decide whether an operation is permanently rejected).
    /// </summary>
    public class ExceptionHandlingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<ExceptionHandlingMiddleware> _logger;

        public ExceptionHandlingMiddleware(
            RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task Invoke(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
            {
                // The client went away mid-request — a POS terminal losing wifi does
                // this constantly. It is not a server fault, and there is no longer
                // anyone to send a response to. Log at Debug and let the connection
                // die, instead of the generic handler recording a 500 "Unhandled
                // server error" and burying real faults in the noise.
                _logger.LogDebug(
                    "Request aborted by client: {Method} {Path}",
                    context.Request.Method, context.Request.Path);
            }
            catch (Exception ex)
            {
                var (status, message) = Map(ex);

                if (status >= 500)
                {
                    _logger.LogError(ex,
                        "Unhandled server error on {Method} {Path} (traceId {TraceId})",
                        context.Request.Method, context.Request.Path, context.TraceIdentifier);
                }
                else
                {
                    _logger.LogWarning("Request rejected ({Status}): {Message}", status, message);
                }

                // A response already on the wire can't be rewritten — let it surface.
                if (context.Response.HasStarted) throw;

                context.Response.Clear();
                context.Response.StatusCode = status;
                context.Response.ContentType = "application/json";

                // 500s deliberately carry no detail (the message is generic so internal
                // state never leaks), which leaves the caller nothing to quote in a bug
                // report. traceId bridges that: it appears in the log line above and is
                // safe to show. Additive field — the { success, message } contract that
                // clients parse is unchanged.
                if (status >= 500)
                {
                    await context.Response.WriteAsJsonAsync(
                        new { success = false, message, traceId = context.TraceIdentifier });
                }
                else
                {
                    await context.Response.WriteAsJsonAsync(new { success = false, message });
                }
            }
        }

        private static (int status, string message) Map(Exception ex) => ex switch
        {
            // InvalidOperationException does double duty: it is this codebase's
            // business-rule signal (~130 throw sites) AND what the data stack throws
            // for genuine infrastructure faults — SqlClient raises it for "The
            // ConnectionString property has not been initialized", LINQ for "Sequence
            // contains no elements". Without this guard a database outage is reported
            // to the POS as `400: The ConnectionString property has not been
            // initialized`, which both misleads the client into treating the request
            // as permanently rejected and leaks server internals.
            //
            // 503 (not 500) is deliberate: it tells the offline sync this is transient
            // and worth retrying, rather than a permanent rejection to discard.
            InvalidOperationException when IsInfrastructureFault(ex) =>
                ((int)HttpStatusCode.ServiceUnavailable,
                 "The server is temporarily unable to reach the database. Please try again."),
            // Business-rule rejections (duplicate name, "in use", out of stock…).
            InvalidOperationException => ((int)HttpStatusCode.BadRequest, ex.Message),
            // Validation failures from FluentValidation pipeline behaviours.
            FluentValidation.ValidationException ve =>
                ((int)HttpStatusCode.BadRequest,
                 string.Join("; ", ve.Errors.Select(e => e.ErrorMessage))),
            // Missing entity.
            KeyNotFoundException => ((int)HttpStatusCode.NotFound, ex.Message),
            // Authorisation / invalid reference guards.
            UnauthorizedAccessException => ((int)HttpStatusCode.Forbidden, ex.Message),
            // Optimistic-concurrency clash: another device changed the row first.
            // 409 tells the offline sync to re-read and retry rather than treating
            // it as a permanent rejection the way a 400 would.
            DbUpdateConcurrencyException =>
                ((int)HttpStatusCode.Conflict,
                 "This record was changed by another device while you were editing it. Reload and try again."),
            // FK constraint (e.g. deleting a product still referenced by a sale).
            DbUpdateException db when IsForeignKeyConflict(db) =>
                ((int)HttpStatusCode.BadRequest,
                 "This record can't be deleted because it is still referenced by other data (for example, it appears in a sale or order)."),
            _ => ((int)HttpStatusCode.InternalServerError,
                  "An unexpected server error occurred."),
        };

        // SQL Server error 547 == foreign-key / constraint conflict.
        private static bool IsForeignKeyConflict(DbUpdateException ex)
            => ex.GetBaseException() is SqlException { Number: 547 };

        /// <summary>
        /// Namespaces that only ever appear for framework/data-layer faults, never
        /// for this application's own business rules.
        /// </summary>
        private static readonly string[] InfrastructureNamespaces =
        {
            "Microsoft.Data.",
            "Microsoft.EntityFrameworkCore.",
            "System.Data.",
        };

        /// <summary>
        /// True when the exception was thrown from inside the data stack rather than
        /// from application code. Uses the throwing method's declaring namespace,
        /// which is reliable here because no application type lives under those roots.
        /// </summary>
        private static bool IsInfrastructureFault(Exception ex)
        {
            var ns = ex.TargetSite?.DeclaringType?.Namespace;
            return ns is not null
                && InfrastructureNamespaces.Any(p => ns.StartsWith(p, StringComparison.Ordinal));
        }
    }
}
