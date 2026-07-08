using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.FiscalItemCommands.Add;
using Api.Commands.FiscalItemCommands.Delete;
using Api.Commands.FiscalItemCommands.Update;
using Api.Queries.FiscalItemQuery;
using System.Collections.Generic;
using System.Threading.Tasks;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FiscalItemsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<FiscalItemDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllFiscalItemsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{plu:int}")]
        public async Task<ActionResult<FiscalItemDto>> GetByPlu(int plu)
        {
            var result = await mediator.Send(new GetFiscalItemByPluQuery { PLU = plu });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<FiscalItemDto>> Add([FromQuery] CreateFiscalItemRequest req)
        {
            var result = await mediator.Send(new AddFiscalItemCommand(req));
            return CreatedAtAction(nameof(GetByPlu), new { plu = result.PLU }, result);
        }

        [HttpPut("[action]/{plu:int}")]
        public async Task<IActionResult> Update(int plu, [FromQuery] UpdateFiscalItemRequest req)
        {
            var result = await mediator.Send(new UpdateFiscalItemCommand(plu, req));
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{plu:int}")]
        public async Task<IActionResult> Delete(int plu)
        {
            var result = await mediator.Send(new DeleteFiscalItemCommand(plu));
            return result ? NoContent() : NotFound();
        }
    }
}