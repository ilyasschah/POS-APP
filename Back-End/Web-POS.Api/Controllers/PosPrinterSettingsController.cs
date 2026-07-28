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
        public async Task<ActionResult<List<PosPrinterSettingsDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required.");
            var result = await mediator.Send(new GetAllPosPrinterSettingsQuery { CompanyId = companyId }, ct);
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PosPrinterSettingsDto>> GetById(int id, CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetPosPrinterSettingsByIdQuery { Id = id }, ct);
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{printerName}")]
        public async Task<ActionResult<PosPrinterSettingsDto>> GetByPrinterName(string printerName, CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetPosPrinterSettingsByPrinterNameQuery { PrinterName = printerName }, ct);
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosPrinterSettingsDto>> Add([FromQuery] int companyId, [FromBody] CreatePosPrinterSettingsRequest req, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required.");
            var result = await mediator.Send(new AddPosPrinterSettingsCommand(req, companyId), ct);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePosPrinterSettingsRequest req, CancellationToken ct = default)
        {
            var ok = await mediator.Send(new UpdatePosPrinterSettingsCommand(id, req), ct);
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id, CancellationToken ct = default)
        {
            var ok = await mediator.Send(new DeletePosPrinterSettingsCommand(id), ct);
            return ok ? NoContent() : NotFound();
        }
    }
}
