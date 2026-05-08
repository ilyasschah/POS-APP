using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.PosPrinterSelectionCommands.Add;
using Api.Commands.PosPrinterSelectionCommands.Delete;
using Api.Commands.PosPrinterSelectionCommands.Update;
using Api.Queries.PosPrinterSelectionQuery;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PosPrinterSelectionsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosPrinterSelectionDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required.");
            var result = await mediator.Send(new GetAllPosPrinterSelectionsQuery { CompanyId = companyId });
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
        public async Task<ActionResult<PosPrinterSelectionDto>> Add([FromQuery] int companyId, [FromBody] CreatePosPrinterSelectionRequest req)
        {
            if (companyId == 0) return BadRequest("Company ID is required.");
            var result = await mediator.Send(new AddPosPrinterSelectionCommand(req, companyId));
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
