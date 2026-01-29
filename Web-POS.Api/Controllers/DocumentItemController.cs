using Products.Api.Commands.DocumentItemCommands.Add;
using Products.Api.Commands.DocumentItemCommands.Delete;
using Products.Api.Queries.DocumentItemQuery;
using Products.Api.Queries.DocumentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;

namespace Products.Api.Controllers
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
        public async Task<ActionResult<DocumentItemDto>> Create([FromBody] CreateDocumentItemRequest request)
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