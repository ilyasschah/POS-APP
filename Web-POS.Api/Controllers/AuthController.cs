using Api.Attributes;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Api.Models;
using Api.Queries.AuthQuery;
using System.Security.Claims;

namespace Api.Controllers;

[SwaggerVisible]
[ApiController]
[Route("api/[controller]")]
public class AuthController(IMediator mediator) : ControllerBase
{
    [HttpPost("[action]")]
    public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest body)
    {
        var response = await mediator.Send(new LoginQuery(body));

        if (!response.Success)
            return Unauthorized(new { message = response.Message });

        return Ok(response);
    }

    /// <summary>
    /// Sliding-window refresh: a still-valid token is exchanged for a fresh one for
    /// the SAME user. [Authorize] is the secure boundary — an expired token can't
    /// self-renew and must re-login. Called by the client on every sync so live
    /// devices never hit expiry on the gated admin-write endpoints.
    /// </summary>
    [Authorize]
    [HttpPost("[action]")]
    public async Task<ActionResult<LoginResponse>> Refresh()
    {
        if (!TryGetClaimInt("userId", out var userId) || !TryGetClaimInt("companyId", out var companyId))
            return Unauthorized();

        var response = await mediator.Send(new IssueUserTokenQuery(userId, companyId));
        if (!response.Success)
            return Unauthorized(new { message = response.Message });

        return Ok(response);
    }

    /// <summary>
    /// Per-user token exchange. The caller presents its (device or user) token and
    /// asks for a token acting as <paramref name="userId"/> — the cashier selected
    /// at the offline PIN login. CompanyId is taken from the caller's token, so a
    /// device can only mint tokens for users in its own tenant. This is what gives
    /// the backend the CURRENT operator's identity + role instead of the device
    /// owner's; offline the client simply keeps using its existing token.
    /// </summary>
    [Authorize]
    [HttpPost("[action]")]
    public async Task<ActionResult<LoginResponse>> UserToken([FromQuery] int userId)
    {
        if (!TryGetClaimInt("companyId", out var companyId))
            return Unauthorized();
        if (userId <= 0)
            return BadRequest(new { message = "userId is required." });

        var response = await mediator.Send(new IssueUserTokenQuery(userId, companyId));
        if (!response.Success)
            return Unauthorized(new { message = response.Message });

        return Ok(response);
    }

    private bool TryGetClaimInt(string claimType, out int value)
        => int.TryParse(User.FindFirstValue(claimType), out value);
}