using Api.Commands.DocumentsCounterCommands.Add;
using Api.Commands.DocumentsCounterCommands.Delete;
using Api.Commands.DocumentsCounterCommands.Update;
using Api.Queries.DocumentsCounterQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DocumentsCountersController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentsCounterDto>>> GetAll(CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetAllDocumentsCountersQuery(), ct);
            return Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<DocumentsCounterDto>> GetByName(string name, CancellationToken ct = default)
        {
            var result = await mediator.Send(new GetDocumentsCounterByNameQuery { Name = name }, ct);
            return result != null ? Ok(result) : NotFound();
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentsCounterDto>> Add([FromQuery] CreateDocumentsCounterRequest req, CancellationToken ct = default)
        {
            var result = await mediator.Send(new AddDocumentsCounterCommand(req), ct);
            return CreatedAtAction(nameof(GetByName), new { name = result.Name }, result);
        }

        [HttpPut("[action]/{name}")]
        public async Task<IActionResult> Update(string name, [FromQuery] UpdateDocumentsCounterRequest req, CancellationToken ct = default)
        {
            var result = await mediator.Send(new UpdateDocumentsCounterCommand(name, req), ct);
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{name}")]
        public async Task<IActionResult> Delete(string name, CancellationToken ct = default)
        {
            var result = await mediator.Send(new DeleteDocumentsCounterCommand(name), ct);
            return result ? NoContent() : NotFound();
        }
    }
}