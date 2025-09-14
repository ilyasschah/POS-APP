using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.CurrencyCommands.Add;
using Products.Api.Commands.CurrencyCommands.Delete;
using Products.Api.Commands.CurrencyCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.CurrenciesQuery;
using Products.Api.Queries.CurrencyQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CurrenciesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CurrencyDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllCurrenciesQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<CurrencyDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetCurrencyByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<CurrencyDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetCurrencyByNameQuery { Name = name });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<CurrencyDto>> Add([FromQuery] CreateCurrencyRequest req)
        {
            var result = await mediator.Send(new AddCurrencyCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateCurrencyRequest req)
        {
            var ok = await mediator.Send(new UpdateCurrencyCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeleteCurrencyCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
