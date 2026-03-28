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
        public async Task<ActionResult<List<CurrencyDto>>> GetAll()
        {
            return Ok(await _mediator.Send(new GetAllCurrencyQuery()));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<CurrencyDto>> GetById([FromQuery] int id)
        {
            return Ok(await _mediator.Send(new GetCurrencyByIdQuery { Id = id }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<CurrencyDto>> GetByName([FromQuery] string name)
        {
            return Ok(await _mediator.Send(new GetCurrencyByNameQuery { Name = name }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<CurrencyDto>> Add([FromBody] CreateCurrencyRequest request)
        {
            var result = await _mediator.Send(new AddCurrencyCommand(request));
            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromQuery] int id, [FromBody] UpdateCurrencyRequest request)
        {
            var result = await _mediator.Send(new UpdateCurrencyCommand(id, request));
            return Ok(new { Success = result });
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id)
        {
            var result = await _mediator.Send(new DeleteCurrencyCommand(id));
            return Ok(new { Message = result ? "Currency deleted successfully" : "Failed to delete currency" });
        }
    }
}