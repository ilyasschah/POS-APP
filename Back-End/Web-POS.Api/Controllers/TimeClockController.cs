using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.TimeClockCommands.BatchSync;
using Api.Master.Services;
using Api.Models;

namespace Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class TimeClockController(
    IMediator mediator,
    ITenantProvisioningService provisioning,
    ICloneAuditService cloneAudit,
    ILogger<TimeClockController> logger) : ControllerBase
{
    // POST /api/TimeClock/BatchSync?companyId=5
    [HttpPost("[action]")]
    public async Task<ActionResult<BatchSyncTimeClockResponse>> BatchSync(
        [FromBody] BatchSyncTimeClockRequest request,
        [FromQuery] int companyId, CancellationToken ct = default)
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
                companyId, deviceId, request.Entries.Select(e => "timeclock:" + e.LocalId));
            if (audit.HasAnomalies)
                logger.LogWarning(
                    "Pillar 5: clone signal (time-clock) for company {CompanyId} from device {DeviceId} — {Count} previously seen on another device.",
                    companyId, deviceId, audit.FlaggedTxnIds.Count);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Pillar 5 clone audit (time-clock) skipped for company {CompanyId}", companyId);
        }

        var result = await mediator.Send(new BatchSyncTimeClockCommand(request, companyId), ct);
        return Ok(result);
    }
}
