using Api.Attributes;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;
using Api.Queries.AuthQuery;

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
}