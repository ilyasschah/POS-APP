using Api.Queries.PosPrinterSettingsQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.PosPrinterSettingsCommands.Add;
using Api.Commands.PosPrinterSettingsCommands.Delete;
using Api.Commands.PosPrinterSettingsCommands.Update;
using Api.Models;

namespace Api.Controllers
{

    [ApiController]
    [Route("api/[controller]")]
    public class PosPrinterSettingsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosPrinterSettingsDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllPosPrinterSettingsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PosPrinterSettingsDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetPosPrinterSettingsByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{printerName}")]
        public async Task<ActionResult<PosPrinterSettingsDto>> GetByPrinterName(string printerName)
        {
            var result = await mediator.Send(new GetPosPrinterSettingsByPrinterNameQuery { PrinterName = printerName });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosPrinterSettingsDto>> Add([FromQuery] CreatePosPrinterSettingsRequest req)
        {
            var result = await mediator.Send(new AddPosPrinterSettingsCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePosPrinterSettingsRequest req)
        {
            var ok = await mediator.Send(new UpdatePosPrinterSettingsCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeletePosPrinterSettingsCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
