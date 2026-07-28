// FILE: Products.Api.Controllers\LoyaltyCardsController.cs

using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.LoyaltyCardCommands.Add;
using Api.Commands.LoyaltyCardCommands.Update;
using Api.Commands.LoyaltyCardCommands.Delete;
using Api.Commands.LoyaltyCardCommands.BatchSync;
using Api.Queries.LoyaltyCardQuery;
using Api.Master.Services;
using Api.Models;

namespace Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class LoyaltyCardsController(IMediator mediator, ITenantProvisioningService provisioning) : ControllerBase
{
    [HttpGet("[action]")]
    public async Task<ActionResult<List<LoyaltyCardDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await mediator.Send(new GetLoyaltyCardsByCompanyQuery(companyId), ct));
    }

    [HttpGet("[action]/{id}")]
    public async Task<ActionResult<LoyaltyCardDto?>> GetById(int id, [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await mediator.Send(new GetLoyaltyCardByIdQuery(id), ct));
    }

    [HttpPost("[action]")]
    public async Task<ActionResult> Add([FromBody] CreateLoyaltyCardRequest request, [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await mediator.Send(new AddLoyaltyCardCommand(request, companyId), ct));
    }

    [HttpPut("[action]")]
    public async Task<IActionResult> Update([FromBody] UpdateLoyaltyCardRequest request, [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        return Ok(await mediator.Send(new UpdateLoyaltyCardCommand(request), ct));
    }

    // The Flutter client deletes via DELETE /api/LoyaltyCards/Delete?id=&companyId=.
    // Without this action that call 404'd, and the offline-first rejection handler
    // reverted the local delete (the card "came back").
    [HttpDelete("[action]")]
    public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");
        if (id <= 0) return BadRequest("Card ID is required.");
        return Ok(await mediator.Send(new DeleteLoyaltyCardCommand(id), ct));
    }

    // POST /api/loyaltycards/batchsync?companyId=5
    [HttpPost("[action]")]
    public async Task<ActionResult<BatchSyncLoyaltyCardsResponse>> BatchSync(
        [FromBody] BatchSyncLoyaltyCardsRequest request,
        [FromQuery] int companyId, CancellationToken ct = default)
    {
        if (companyId <= 0) return BadRequest("Company ID is required.");

        // Pillar 4: seat enforcement at sync ingress.
        var seatBlock = await SeatGuard.CheckAsync(Request, provisioning, companyId);
        if (seatBlock != null) return seatBlock;

        var result = await mediator.Send(new BatchSyncLoyaltyCardsCommand(request, companyId), ct);
        return Ok(result);
    }
}
