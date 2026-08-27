using Api.Admin;
using Microsoft.AspNetCore.Authorization;

namespace Api.Attributes;

/// <summary>
/// Restricts an endpoint to the platform operator — the admin portal's signed-in
/// account, not a POS or dashboard token.
///
/// ## Why these endpoints needed it
///
/// <c>Master/Tenants</c>, <c>Subscriptions</c> and <c>Devices</c> take no
/// <c>companyId</c>, so <c>CompanyScopeFilter</c> has nothing to compare and
/// leaves them alone — correctly, since they are meant to span every tenant. That
/// left them protected only by the global <c>FallbackPolicy</c>, i.e. by ANY
/// authenticated user: a cashier's token could list every company on the
/// platform, its subscriptions and its registered devices. <c>Provision</c> and
/// <c>CheckDevice</c> were worse, being writes that create tenants and consume
/// device seats in companies the caller has nothing to do with.
///
/// ## Why the portal's cookie and not a new claim
///
/// A super-admin claim on the POS JWT would be a second answer to a question this
/// codebase already answers. The admin portal (<c>/admin</c>, Razor Pages) is the
/// control plane, it has its own accounts and its own cookie scheme, and nothing
/// calls these endpoints over HTTP today — so pointing them at the identity that
/// already means "platform operator" costs nothing and invents nothing.
///
/// ⚠️ <c>AddAuthenticationSchemes</c> is load-bearing and lives in the policy
/// itself (see <c>Program.cs</c>): the API's default scheme is JwtBearer, so a
/// policy that does not name the cookie scheme would authenticate against the
/// bearer handler and never see the portal cookie.
///
/// Note that these actions still need <c>[AllowCrossCompany]</c> where they carry
/// a <c>companyId</c>: the portal's principal has no company claim of its own, so
/// the tenant filter would otherwise refuse it.
/// </summary>
public sealed class ControlPlaneAttribute : AuthorizeAttribute
{
    public ControlPlaneAttribute()
    {
        Policy = AdminPortalAuth.PolicyName;
    }
}
