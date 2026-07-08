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
        public async Task<ActionResult<List<DocumentsCounterDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllDocumentsCountersQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<DocumentsCounterDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetDocumentsCounterByNameQuery { Name = name });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentsCounterDto>> Add([FromQuery] CreateDocumentsCounterRequest req)
        {
            var result = await mediator.Send(new AddDocumentsCounterCommand(req));
            return CreatedAtAction(nameof(GetByName), new { name = result.Name }, result);
        }

        [HttpPut("[action]/{name}")]
        public async Task<IActionResult> Update(string name, [FromQuery] UpdateDocumentsCounterRequest req)
        {
            var result = await mediator.Send(new UpdateDocumentsCounterCommand(name, req));
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{name}")]
        public async Task<IActionResult> Delete(string name)
        {
            var result = await mediator.Send(new DeleteDocumentsCounterCommand(name));
            return result ? NoContent() : NotFound();
        }
    }
}