using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.StartingCashCommands.Add;
using Sales.Api.Commands.StartingCashCommands.Delete;
using Sales.Api.Commands.StartingCashCommands.Update;
using Sales.Api.Models;
using Sales.Api.Queries.StartingCashQuery;

namespace Sales.Api.Controllers
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
    }
}
