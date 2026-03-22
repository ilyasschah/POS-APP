using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.PosPrinterSelectionSettingsCommands.Add;
using Api.Commands.PosPrinterSelectionSettingsCommands.Delete;
using Api.Commands.PosPrinterSelectionSettingsCommands.Update;
using Api.Queries.PosPrinterSelectionSettingsQuery;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PosPrinterSelectionSettingsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosPrinterSelectionSettingsDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllPosPrinterSelectionSettingsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PosPrinterSelectionSettingsDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetPosPrinterSelectionSettingsByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{posPrinterSelectionId:int}")]
        public async Task<ActionResult<List<PosPrinterSelectionSettingsDto>>> GetBySelectionId(int posPrinterSelectionId)
        {
            var result = await mediator.Send(new GetPosPrinterSelectionSettingsBySelectionIdQuery { PosPrinterSelectionId = posPrinterSelectionId });
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosPrinterSelectionSettingsDto>> Add([FromQuery] CreatePosPrinterSelectionSettingsRequest req)
        {
            var result = await mediator.Send(new AddPosPrinterSelectionSettingsCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePosPrinterSelectionSettingsRequest req)
        {
            var ok = await mediator.Send(new UpdatePosPrinterSelectionSettingsCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeletePosPrinterSelectionSettingsCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
