using Api.Attributes;
using Api.Commands.CurrenciesCommands.Update;
using Api.Commands.CurrenciesCommands.Add;
using Api.Commands.CurrenciesCommands.Delete;
using Api.Models;
using Api.Queries.CurrenciesQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class CurrenciesController : ControllerBase
    {
        private readonly IMediator _mediator;

        public CurrenciesController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<CurrencyDto>>> GetAll(CancellationToken ct = default)
        {
            return Ok(await _mediator.Send(new GetAllCurrencyQuery(), ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<CurrencyDto>> GetById([FromQuery] int id, CancellationToken ct = default)
        {
            return Ok(await _mediator.Send(new GetCurrencyByIdQuery { Id = id }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<CurrencyDto>> GetByName([FromQuery] string name, CancellationToken ct = default)
        {
            return Ok(await _mediator.Send(new GetCurrencyByNameQuery { Name = name }, ct));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<CurrencyDto>> Add([FromBody] CreateCurrencyRequest request, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new AddCurrencyCommand(request), ct);
            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromQuery] int id, [FromBody] UpdateCurrencyRequest request, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new UpdateCurrencyCommand(id, request), ct);
            return Ok(new { Success = result });
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new DeleteCurrencyCommand(id), ct);
            return Ok(new { Message = result ? "Currency deleted successfully" : "Failed to delete currency" });
        }
    }
}