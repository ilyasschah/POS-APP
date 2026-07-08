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
        public async Task<ActionResult<List<StartingCashDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllStartingCashQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<StartingCashDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetStartingCashByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{userId:int}")]
        public async Task<ActionResult<List<StartingCashDto>>> GetByUserId(int userId)
        {
            var result = await mediator.Send(new GetStartingCashByUserIdQuery { UserId = userId });
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<StartingCashDto>> Add([FromQuery] CreateStartingCashRequest req)
        {
            var result = await mediator.Send(new AddStartingCashCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateStartingCashRequest req)
        {
            var ok = await mediator.Send(new UpdateStartingCashCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeleteStartingCashCommand(id));
            return ok ? NoContent() : NotFound();
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<StartingCashDto>>> GetByDateRange(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? userId = null)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (endDate.Date < startDate.Date) return BadRequest("End date must be on or after start date");

            var result = await mediator.Send(new GetStartingCashByDateRangeQuery
            {
                CompanyId = companyId,
                StartDate = startDate,
                EndDate   = endDate,
                UserId    = userId,
            });

            return Ok(result);
        }
    }
}
