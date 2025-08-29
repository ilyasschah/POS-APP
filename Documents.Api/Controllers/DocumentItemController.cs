using Documents.Api.Commands.DocumentItemCommands.Add;
using Documents.Api.Commands.DocumentItemCommands.Delete;
using Documents.Api.Models;
using Documents.Api.Queries.DocumentItemQuery;
using Documents.Api.Queries.DocumentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Documents.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentItemController(IMediator mediator) : ControllerBase
    {
        //GetAllDocumentCatogory
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentItemDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllDocumentItemQuery()));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentItemDto>>> GetGetDocumentItemsByDocumentId()
        {
            return Ok(await mediator.Send(new GetDocumentItemsByDocumentIdQuery()));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentItemDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetDocumentByIdQuery(id)));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentItemDto>> Create([FromQuery] CreateDocumentItemRequest request)
        {
            return Ok(await mediator.Send(new AddDocumentItemCommand(request)));
        }
        //DELETE: api/DocumentItem/delete/5
        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteDocumentItemCommand(id)));
        }
    }
}