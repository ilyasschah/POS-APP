using System.Reflection;
using System.Security.Claims;
using Api.Attributes;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Api.Filters;

/// <summary>
/// Refuses any request that names a company other than the caller's own.
///
/// ## The hole this closes
///
/// Tenant scope was carried entirely by a <c>companyId</c> in the query string
/// or the request body, and nothing ever compared it to the company on the
/// caller's token. Every one of the ~250 scoped endpoints therefore answered for
/// whatever company the URL asked about: <c>GET /api/Dashboard/GetDashboardData
/// ?companyId=25</c> returned company 25's takings to a cashier signed in to
/// company 41, and the same edit worked on documents, payments, cash movements,
/// customers and users. Authentication was enforced; authorisation was not.
///
/// ## Why a global filter and not a check per endpoint
///
/// Because the mistake is one nobody makes on purpose. A check written into each
/// action is a check that the 251st endpoint forgets, and the failure is silent —
/// the endpoint works perfectly, for the wrong tenant. This mirrors the
/// <c>FallbackPolicy</c> already in <c>Program.cs</c>: fail closed by default,
/// opt out explicitly with <see cref="AllowCrossCompanyAttribute"/>, and a
/// newly-added controller is protected before anyone remembers it exists.
///
/// ## What it inspects
///
/// The caller's company is the <c>companyId</c> claim minted in
/// <c>TokenService.CreateJwt</c>. The request's company is taken from, in order:
/// any action argument named <c>companyId</c>; any <c>CompanyId</c> property on a
/// bound body object; the raw <c>companyId</c> query value (a backstop for a
/// value bound under a name this filter does not anticipate); and any parameter
/// named by <see cref="CompanyScopedByAttribute"/>.
///
/// ## What it deliberately does not do
///
/// A request that names NO company is left alone — many endpoints legitimately
/// take none, and inventing a rule for them here would break them. Nor does it
/// rewrite the incoming value to the caller's own company: silently answering a
/// different question than the one asked is how this class of bug hides. A
/// mismatch is a 403 the client can see.
/// </summary>
public sealed class CompanyScopeFilter : IAsyncActionFilter
{
    public const string ClaimName = "companyId";

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context, ActionExecutionDelegate next)
    {
        if (context.ActionDescriptor is not ControllerActionDescriptor descriptor)
        {
            await next();
            return;
        }

        // Anonymous endpoints have no principal to compare against — the login
        // call itself is the obvious one. They are guarded by their own logic.
        var endpoint = context.HttpContext.GetEndpoint();
        if (endpoint?.Metadata.GetMetadata<IAllowAnonymous>() is not null)
        {
            await next();
            return;
        }

        if (HasAttribute<AllowCrossCompanyAttribute>(descriptor))
        {
            await next();
            return;
        }

        var requested = RequestedCompanyIds(context, descriptor).ToList();
        if (requested.Count == 0)
        {
            await next();
            return;
        }

        var callerCompanyId = CompanyIdOf(context.HttpContext.User);

        // A token with no company cannot be scoped to one, so a request that
        // names a company is refused rather than allowed through unchecked. The
        // admin portal's cookie principal never reaches a controller action —
        // it serves Razor Pages, which do not run action filters.
        if (callerCompanyId is null or <= 0)
        {
            context.Result = Forbid(
                "This account is not attached to a company, so it cannot read "
                + "company-scoped data.");
            return;
        }

        foreach (var id in requested)
        {
            if (id != callerCompanyId)
            {
                context.Result = Forbid(
                    "This request names a company you are not signed in to.");
                return;
            }
        }

        await next();
    }

    /// <summary>Every company id this request is asking about.</summary>
    private static IEnumerable<int> RequestedCompanyIds(
        ActionExecutingContext context, ControllerActionDescriptor descriptor)
    {
        var seen = new HashSet<int>();
        var extraNames = ExtraParameterNames(descriptor);

        foreach (var (name, value) in context.ActionArguments)
        {
            if (value is null) continue;

            var namesACompany =
                string.Equals(name, "companyId", StringComparison.OrdinalIgnoreCase)
                || extraNames.Contains(name);

            if (namesACompany && TryAsInt(value, out var direct))
            {
                if (seen.Add(direct)) yield return direct;
                continue;
            }

            // A bound body object carrying its own CompanyId — DocumentDto,
            // ShiftDto, ProductDto and a dozen others do.
            foreach (var nested in NestedCompanyIds(value, extraNames))
            {
                if (seen.Add(nested)) yield return nested;
            }
        }

        // Backstop: the value as it arrived on the wire. Catches an endpoint
        // whose parameter is spelled differently, and the case where model
        // binding dropped the argument entirely.
        if (context.HttpContext.Request.Query.TryGetValue("companyId", out var raw)
            && int.TryParse(raw.FirstOrDefault(), out var fromQuery)
            && fromQuery > 0
            && seen.Add(fromQuery))
        {
            yield return fromQuery;
        }
    }

    /// <summary>
    /// `CompanyId` read off a bound object, one level deep.
    ///
    /// One level on purpose: a whole-object graph walk on every request would be
    /// a cost paid by every endpoint to catch a shape none of the DTOs use.
    /// </summary>
    private static IEnumerable<int> NestedCompanyIds(
        object value, HashSet<string> extraNames)
    {
        var type = value.GetType();
        if (type.IsPrimitive || value is string || value is DateTime) yield break;

        // Collections of DTOs (bulk sync posts a list of documents).
        if (value is System.Collections.IEnumerable items and not string)
        {
            foreach (var item in items)
            {
                if (item is null) continue;
                foreach (var id in PropertyCompanyIds(item, extraNames))
                {
                    yield return id;
                }
            }
            yield break;
        }

        foreach (var id in PropertyCompanyIds(value, extraNames))
        {
            yield return id;
        }
    }

    /// <summary>
    /// The company ids carried as properties of one bound object: `CompanyId`,
    /// plus anything <see cref="CompanyScopedByAttribute"/> named — which is how
    /// `CompanyController`'s plain `Id` is brought under the check.
    /// </summary>
    private static IEnumerable<int> PropertyCompanyIds(
        object value, HashSet<string> extraNames)
    {
        var type = value.GetType();
        foreach (var name in extraNames.Append("CompanyId"))
        {
            var property = type.GetProperty(name,
                BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase);
            if (property is not null
                && TryAsInt(property.GetValue(value), out var id)
                && id > 0)
            {
                yield return id;
            }
        }
    }

    private static bool TryAsInt(object? value, out int result)
    {
        switch (value)
        {
            case int i:
                result = i;
                return true;
            case long l when l is >= int.MinValue and <= int.MaxValue:
                result = (int)l;
                return true;
            default:
                result = 0;
                return false;
        }
    }

    private static HashSet<string> ExtraParameterNames(
        ControllerActionDescriptor descriptor)
    {
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var attribute in
                 descriptor.MethodInfo.GetCustomAttributes<CompanyScopedByAttribute>(true))
        {
            names.UnionWith(attribute.ParameterNames);
        }
        foreach (var attribute in
                 descriptor.ControllerTypeInfo.GetCustomAttributes<CompanyScopedByAttribute>(true))
        {
            names.UnionWith(attribute.ParameterNames);
        }
        return names;
    }

    private static bool HasAttribute<T>(ControllerActionDescriptor descriptor)
        where T : Attribute =>
        descriptor.MethodInfo.GetCustomAttributes<T>(true).Any()
        || descriptor.ControllerTypeInfo.GetCustomAttributes<T>(true).Any();

    /// <summary>The company on the caller's token, or null when it carries none.</summary>
    public static int? CompanyIdOf(ClaimsPrincipal user)
    {
        var raw = user.FindFirstValue(ClaimName);
        return int.TryParse(raw, out var id) ? id : null;
    }

    private static ObjectResult Forbid(string message) =>
        new(new { success = false, message })
        {
            StatusCode = StatusCodes.Status403Forbidden,
        };
}
