using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.PosPrinterSelectionCommands.Add;
using Products.Api.Commands.PosPrinterSelectionCommands.Delete;
using Products.Api.Commands.PosPrinterSelectionCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.PosPrinterSelectionQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PosPrinterSelectionsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosPrinterSelectionDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllPosPrinterSelectionsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PosPrinterSelectionDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetPosPrinterSelectionByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{key}")]
        public async Task<ActionResult<PosPrinterSelectionDto>> GetByKey(string key)
        {
            var result = await mediator.Send(new GetPosPrinterSelectionByKeyQuery { Key = key });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosPrinterSelectionDto>> Add([FromQuery] CreatePosPrinterSelectionRequest req)
        {
            var result = await mediator.Send(new AddPosPrinterSelectionCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePosPrinterSelectionRequest req)
        {
            var ok = await mediator.Send(new UpdatePosPrinterSelectionCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeletePosPrinterSelectionCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
