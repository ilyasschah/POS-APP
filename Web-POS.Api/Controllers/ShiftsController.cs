using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ShiftCommands.BatchSync;
using Api.Models;
using Api.Repository;

namespace Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class ShiftsController(IMediator mediator, ShiftRepository repository) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<ShiftDto>>> History([FromQuery] int companyId)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        var shifts = await repository.GetByCompanyIdAsync(companyId);
        var dtos = shifts.Select(s => new ShiftDto
        {
            Id = s.Id,
            CompanyId = s.CompanyId,
            UserId = s.UserId,
            OpenedAt = s.OpenedAt,
            ClosedAt = s.ClosedAt,
            StartingCash = s.StartingCash,
            ActualEndingCash = s.ActualEndingCash,
            Status = s.Status,
            LastModified = s.LastModified,
        }).ToList();
        return Ok(dtos);
    }

    // POST /api/shifts/batchsync?companyId=5
    [HttpPost("[action]")]
    public async Task<ActionResult<BatchSyncShiftsResponse>> BatchSync(
        [FromBody] BatchSyncShiftsRequest request,
        [FromQuery] int companyId)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        var result = await mediator.Send(new BatchSyncShiftsCommand(request, companyId));
        return Ok(result);
    }
}
