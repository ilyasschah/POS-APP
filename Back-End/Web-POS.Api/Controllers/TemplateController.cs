using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.TemplateCommands.Add;
using Api.Commands.TemplateCommands.Delete;
using Api.Commands.TemplateCommands.Update;
using Api.Queries.TemplateQuery;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TemplatesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<TemplateDto>>> GetAll(CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetAllTemplatesQuery(), ct);
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<TemplateDto>> GetById(int id, CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetTemplateByIdQuery { Id = id }, ct);
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<TemplateDto>> GetByName(string name, CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetTemplateByNameQuery { Name = name }, ct);
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<TemplateDto>> Add([FromQuery] CreateTemplateRequest req, CancellationToken ct = default)
        {
            var result = await mediator.Send(new AddTemplateCommand(req), ct);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateTemplateRequest req, CancellationToken ct = default)
        {
            var ok = await mediator.Send(new UpdateTemplateCommand(id, req), ct);
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id, CancellationToken ct = default)
        {
            var ok = await mediator.Send(new DeleteTemplateCommand(id), ct);
            return ok ? NoContent() : NotFound();
        }
    }
}
