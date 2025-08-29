using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.StartingCashCommands.Add;
using Sales.Api.Commands.StartingCashCommands.Delete;
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
            return result != null ? Ok(result) : NotFound();
        }

        [HttpGet("[action]/ByUser/{userId:int}")]
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

        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await mediator.Send(new DeleteStartingCashCommand(id));
            return result ? NoContent() : NotFound();
        }
    }
}