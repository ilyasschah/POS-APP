using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.TimeClockCommands.BatchSync;
using Api.Models;

namespace Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class TimeClockController(IMediator mediator) : ControllerBase
{
    // POST /api/TimeClock/BatchSync?companyId=5
    [HttpPost("[action]")]
    public async Task<ActionResult<BatchSyncTimeClockResponse>> BatchSync(
        [FromBody] BatchSyncTimeClockRequest request,
        [FromQuery] int companyId)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        var result = await mediator.Send(new BatchSyncTimeClockCommand(request, companyId));
        return Ok(result);
    }
}
