using Api.Attributes;
using Api.Commands.UserDevicePinCommands;
using Api.Models;
using Api.Queries.UserDevicePinQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[SwaggerVisible]
[Route("api/[controller]")]
[ApiController]
public class UserDevicePinsController(IMediator mediator) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<UserDevicePinDto>>> GetActiveDevices([FromQuery] int companyId, [FromQuery] int? userId, CancellationToken ct = default)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new GetActiveDevicesQuery { CompanyId = companyId, UserId = userId }, ct);
        return Ok(result);
    }

    [HttpPost("[action]")]
    public async Task<IActionResult> SetDevicePin([FromBody] SetDevicePinRequest request, [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        if (string.IsNullOrWhiteSpace(request.Pin) || request.Pin.Length < 4)
            return BadRequest(new { message = "PIN must be at least 4 digits." });
        var hashedPin = await mediator.Send(new SetDevicePinCommand(request, companyId), ct);
        return Ok(new { Success = true, Message = "Device PIN set successfully.", HashedPin = hashedPin });
    }

    [HttpDelete("[action]")]
    public async Task<ActionResult> RevokeDevice([FromBody] RevokeDeviceRequest request,[FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId == 0) return BadRequest("Company ID is required");
        var result = await mediator.Send(new RevokeDeviceCommand(request, companyId), ct);
        if (!result) return NotFound("Device or PIN not found.");
        return Ok(new { Success = true, Message = "Device revoked successfully" });
    }
}