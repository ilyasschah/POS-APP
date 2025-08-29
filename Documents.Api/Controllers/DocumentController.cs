using Documents.Api.Commands.DocumentCommands.Add;
using Documents.Api.Commands.DocumentCommands.Delete;
using Documents.Api.Commands.DocumentCommands.Update;
using Documents.Api.Models;
using Documents.Api.Queries.DocumentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Documents.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentController (IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllDocumentsQuery()));
        }
        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<DocumentDto?>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetDocumentByIdQuery (id)));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentDto>>> GetByNumberAsync([FromBody] string number)
        {
            return Ok(await mediator.Send(new GetDocumentByNumberQuery(number)));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentDto>> Add([FromBody] CreateDocumentRequest req)
        {
            return Ok(await mediator.Send(new AddDocumentCommand(req)));
        }
        [HttpPost("[action]")]
        public async Task<IActionResult> Update([FromQuery] UpdateDocumentRequest updaterequest)
        {
            return Ok(await mediator.Send(new UpdateDocumentCommand(updaterequest)));
        }
        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteDocumentCommand (id)));
        }
    }
}
