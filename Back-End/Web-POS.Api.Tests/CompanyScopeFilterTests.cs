using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Security.Claims;
using System.Threading.Tasks;
using Api.Attributes;
using Api.Filters;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Xunit;

namespace Api.Tests;

/// <summary>
/// Tenant isolation. Every endpoint took its <c>companyId</c> from the caller
/// and nothing compared it to the token, so a signed-in cashier could read any
/// company's dashboard, documents or cash by editing the URL. These cover the
/// shapes that hole came in: the query string, a body DTO, a list of DTOs, and a
/// company id spelled <c>id</c>.
/// </summary>
public class CompanyScopeFilterTests
{
    // ── Test surface ─────────────────────────────────────────────────────────

    private sealed class Dto
    {
        public int CompanyId { get; set; }
    }

    private sealed class CompanyDto
    {
        public int Id { get; set; }
    }

    private sealed class ProbeController
    {
        public void Scoped(int companyId) { }

        public void Body(Dto request) { }

        public void Bulk(List<Dto> rows) { }

        [CompanyScopedBy("id")]
        public void ById(int id) { }

        [CompanyScopedBy("id")]
        public void ByIdBody(CompanyDto request) { }

        [AllowCrossCompany]
        public void ControlPlane(int companyId) { }

        public void Unscoped(int productId) { }
    }

    /// <summary>Runs the filter and reports whether the action was allowed to run.</summary>
    private static async Task<(bool reachedAction, int? statusCode)> Run(
        string method,
        IDictionary<string, object?> arguments,
        int? callerCompanyId,
        string? queryCompanyId = null)
    {
        var http = new DefaultHttpContext();
        if (callerCompanyId is not null)
        {
            http.User = new ClaimsPrincipal(new ClaimsIdentity(
                new[] { new Claim(CompanyScopeFilter.ClaimName, callerCompanyId.ToString()!) },
                authenticationType: "Test"));
        }
        if (queryCompanyId is not null)
        {
            http.Request.QueryString = new QueryString($"?companyId={queryCompanyId}");
        }

        var descriptor = new ControllerActionDescriptor
        {
            ControllerTypeInfo = typeof(ProbeController).GetTypeInfo(),
            MethodInfo = typeof(ProbeController).GetMethod(method)!,
            ActionName = method,
            ControllerName = nameof(ProbeController),
        };

        var actionContext = new ActionContext(http, new RouteData(), descriptor);
        var executing = new ActionExecutingContext(
            actionContext,
            new List<IFilterMetadata>(),
            arguments,
            controller: new ProbeController());

        var reached = false;
        await new CompanyScopeFilter().OnActionExecutionAsync(executing, () =>
        {
            reached = true;
            return Task.FromResult(new ActionExecutedContext(
                actionContext, new List<IFilterMetadata>(), new ProbeController()));
        });

        var status = (executing.Result as ObjectResult)?.StatusCode;
        return (reached, status);
    }

    // ── The hole itself ──────────────────────────────────────────────────────

    [Fact]
    public async Task A_request_for_another_companys_data_is_refused()
    {
        // The reported case: signed in to 41, asking about 25.
        var (reached, status) = await Run(
            nameof(ProbeController.Scoped),
            new Dictionary<string, object?> { ["companyId"] = 25 },
            callerCompanyId: 41);

        Assert.False(reached);
        Assert.Equal(StatusCodes.Status403Forbidden, status);
    }

    [Fact]
    public async Task A_request_for_your_own_company_runs()
    {
        var (reached, status) = await Run(
            nameof(ProbeController.Scoped),
            new Dictionary<string, object?> { ["companyId"] = 41 },
            callerCompanyId: 41);

        Assert.True(reached);
        Assert.Null(status);
    }

    [Fact]
    public async Task A_body_dto_naming_another_company_is_refused()
    {
        var (reached, _) = await Run(
            nameof(ProbeController.Body),
            new Dictionary<string, object?> { ["request"] = new Dto { CompanyId = 25 } },
            callerCompanyId: 41);

        Assert.False(reached);
    }

    [Fact]
    public async Task One_foreign_row_in_a_bulk_post_is_enough_to_refuse_it()
    {
        // Bulk sync posts a list. A single smuggled row must not ride along with
        // legitimate ones.
        var rows = new List<Dto> { new() { CompanyId = 41 }, new() { CompanyId = 25 } };
        var (reached, _) = await Run(
            nameof(ProbeController.Bulk),
            new Dictionary<string, object?> { ["rows"] = rows },
            callerCompanyId: 41);

        Assert.False(reached);
    }

    [Fact]
    public async Task A_company_id_spelled_id_is_checked_when_the_action_says_so()
    {
        var (refused, _) = await Run(
            nameof(ProbeController.ById),
            new Dictionary<string, object?> { ["id"] = 25 },
            callerCompanyId: 41);
        Assert.False(refused);

        var (allowed, _) = await Run(
            nameof(ProbeController.ById),
            new Dictionary<string, object?> { ["id"] = 41 },
            callerCompanyId: 41);
        Assert.True(allowed);
    }

    [Fact]
    public async Task A_company_id_spelled_id_on_a_body_is_checked_too()
    {
        var (reached, _) = await Run(
            nameof(ProbeController.ByIdBody),
            new Dictionary<string, object?> { ["request"] = new CompanyDto { Id = 25 } },
            callerCompanyId: 41);

        Assert.False(reached);
    }

    // ── The value on the wire, not just the bound argument ───────────────────

    [Fact]
    public async Task The_query_string_is_checked_even_when_no_argument_bound_it()
    {
        // Backstop for an endpoint that reads companyId some other way. Without
        // this, "the parameter is named differently" reopens the hole.
        var (reached, _) = await Run(
            nameof(ProbeController.Unscoped),
            new Dictionary<string, object?> { ["productId"] = 7 },
            callerCompanyId: 41,
            queryCompanyId: "25");

        Assert.False(reached);
    }

    // ── What must keep working ───────────────────────────────────────────────

    [Fact]
    public async Task An_action_that_names_no_company_is_left_alone()
    {
        var (reached, status) = await Run(
            nameof(ProbeController.Unscoped),
            new Dictionary<string, object?> { ["productId"] = 7 },
            callerCompanyId: 41);

        Assert.True(reached);
        Assert.Null(status);
    }

    [Fact]
    public async Task The_control_plane_may_name_another_company()
    {
        // Provisioning a tenant and checking a device seat at master login both
        // act on a company that is not the caller's own.
        var (reached, _) = await Run(
            nameof(ProbeController.ControlPlane),
            new Dictionary<string, object?> { ["companyId"] = 25 },
            callerCompanyId: 41);

        Assert.True(reached);
    }

    // ── Fail closed ──────────────────────────────────────────────────────────

    [Fact]
    public async Task A_token_with_no_company_cannot_ask_about_one()
    {
        var (reached, status) = await Run(
            nameof(ProbeController.Scoped),
            new Dictionary<string, object?> { ["companyId"] = 25 },
            callerCompanyId: null);

        Assert.False(reached);
        Assert.Equal(StatusCodes.Status403Forbidden, status);
    }

    [Fact]
    public async Task Every_scoped_controller_action_is_covered_or_exempt()
    {
        // A guard against the way this bug returns: a new controller that takes a
        // companyId and quietly predates the filter. Nothing to assert per-action
        // — the filter is global — so this asserts the exemption list stays
        // small and deliberate.
        var exempt = typeof(Api.Controllers.MasterController).Assembly
            .GetTypes()
            .Where(t => typeof(ControllerBase).IsAssignableFrom(t))
            .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
                .Select(m => (Type: t, Method: m)))
            .Where(x => x.Method.GetCustomAttributes<AllowCrossCompanyAttribute>(true).Any()
                        || x.Type.GetCustomAttributes<AllowCrossCompanyAttribute>(true).Any())
            .Select(x => $"{x.Type.Name}.{x.Method.Name}")
            .OrderBy(n => n)
            .ToList();

        Assert.Equal(
            new[]
            {
                "CompanyController.GetAll",
                "MasterController.CheckDevice",
                "MasterController.Provision",
            },
            exempt);
    }

    [Fact]
    public void The_control_plane_endpoints_are_not_reachable_with_a_pos_token()
    {
        // Tenants/Subscriptions/Devices carry no companyId, so the tenant filter
        // has nothing to compare — they were protected only by "any authenticated
        // user", which included every cashier. [ControlPlane] is what closes that,
        // and this asserts none of them slips back to the fallback policy.
        var master = typeof(Api.Controllers.MasterController);
        foreach (var name in new[]
                 {
                     nameof(Api.Controllers.MasterController.Tenants),
                     nameof(Api.Controllers.MasterController.Subscriptions),
                     nameof(Api.Controllers.MasterController.Devices),
                     nameof(Api.Controllers.MasterController.Provision),
                     nameof(Api.Controllers.MasterController.CheckDevice),
                     nameof(Api.Controllers.MasterController.CloneAlerts),
                 })
        {
            var method = master.GetMethod(name);
            Assert.NotNull(method);
            var attribute = method!
                .GetCustomAttributes<ControlPlaneAttribute>(true)
                .SingleOrDefault();
            Assert.True(attribute is not null, $"{name} is missing [ControlPlane]");
            Assert.Equal(Api.Admin.AdminPortalAuth.PolicyName, attribute!.Policy);
        }
    }
}
