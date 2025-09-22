using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ApplicationPropertyCommands.Add;
using Products.Api.Commands.ApplicationPropertyCommands.Delete;
using Products.Api.Commands.ApplicationPropertyCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.ApplicationPropertyQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ApplicationPropertiesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ApplicationPropertyDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllApplicationPropertiesQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<ApplicationPropertyDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetApplicationPropertyByNameQuery { Name = name });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")] // body via query per your rule
        public async Task<ActionResult<ApplicationPropertyDto>> Add([FromQuery] CreateApplicationPropertyRequest req)
        {
            var result = await mediator.Send(new AddApplicationPropertyCommand(req));
            // key is Name, so use GetByName
            return CreatedAtAction(nameof(GetByName), new { name = result.Name }, result);
        }

        [HttpPut("[action]/{originalName}")]
        public async Task<IActionResult> Update(string originalName, [FromQuery] UpdateApplicationPropertyRequest req)
        {
            var ok = await mediator.Send(new UpdateApplicationPropertyCommand(originalName, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{name}")]
        public async Task<IActionResult> Delete(string name)
        {
            var ok = await mediator.Send(new DeleteApplicationPropertyCommand(name));
            return ok ? NoContent() : NotFound();
        }
    }
}
