using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.TemplateCommands.Add;
using Products.Api.Commands.TemplateCommands.Delete;
using Products.Api.Commands.TemplateCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.TemplateQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TemplatesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<TemplateDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllTemplatesQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<TemplateDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetTemplateByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<TemplateDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetTemplateByNameQuery { Name = name });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<TemplateDto>> Add([FromQuery] CreateTemplateRequest req)
        {
            var result = await mediator.Send(new AddTemplateCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateTemplateRequest req)
        {
            var ok = await mediator.Send(new UpdateTemplateCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeleteTemplateCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
