using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ShiftCommands.BatchSync;
using Api.Master.Services;
using Api.Models;
using Api.Repository;

namespace Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class ShiftsController(
    IMediator mediator,
    ShiftRepository repository,
    ITenantProvisioningService provisioning,
    ICloneAuditService cloneAudit,
    ILogger<ShiftsController> logger) : ControllerBase
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

        // Pillar 4: seat enforcement at sync ingress.
        var seatBlock = await SeatGuard.CheckAsync(Request, provisioning, companyId);
        if (seatBlock != null) return seatBlock;

        // Pillar 5: clone / duplication audit (detection only, non-fatal).
        try
        {
            var deviceId = Request.Headers["X-Device-Id"].ToString();
            var audit = await cloneAudit.RecordAndCheckAsync(
                companyId, deviceId, request.Shifts.Select(s => "shift:" + s.LocalId));
            if (audit.HasAnomalies)
                logger.LogWarning(
                    "Pillar 5: clone signal (shifts) for company {CompanyId} from device {DeviceId} — {Count} previously seen on another device.",
                    companyId, deviceId, audit.FlaggedTxnIds.Count);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Pillar 5 clone audit (shifts) skipped for company {CompanyId}", companyId);
        }

        var result = await mediator.Send(new BatchSyncShiftsCommand(request, companyId));
        return Ok(result);
    }
}
