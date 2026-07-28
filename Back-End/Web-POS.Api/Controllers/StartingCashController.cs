using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.StartingCashCommands.Add;
using Api.Commands.StartingCashCommands.Delete;
using Api.Commands.StartingCashCommands.Update;
using Api.Queries.StartingCashQuery;
using Api.Models;
using System;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class StartingCashController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<StartingCashDto>>> GetAll(CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetAllStartingCashQuery(), ct);
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<StartingCashDto>> GetById(int id, CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetStartingCashByIdQuery { Id = id }, ct);
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{userId:int}")]
        public async Task<ActionResult<List<StartingCashDto>>> GetByUserId(int userId, CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetStartingCashByUserIdQuery { UserId = userId }, ct);
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<StartingCashDto>> Add([FromQuery] CreateStartingCashRequest req, CancellationToken ct = default)
        {
            var result = await mediator.Send(new AddStartingCashCommand(req), ct);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateStartingCashRequest req, CancellationToken ct = default)
        {
            var ok = await mediator.Send(new UpdateStartingCashCommand(id, req), ct);
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id, CancellationToken ct = default)
        {
            var ok = await mediator.Send(new DeleteStartingCashCommand(id), ct);
            return ok ? NoContent() : NotFound();
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<StartingCashDto>>> GetByDateRange(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? userId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetStartingCashByDateRangeQuery
            {
                CompanyId = companyId,
                StartDate = startDate,
                EndDate   = endDate,
                UserId    = userId,
            }, ct);

            return Ok(result);
        }
    }
}
