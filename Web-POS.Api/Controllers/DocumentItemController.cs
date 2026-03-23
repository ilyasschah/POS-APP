using Api.Commands.DocumentItemCommands.Add;
using Api.Commands.DocumentItemCommands.Delete;
using Api.Queries.DocumentItemQuery;
using Api.Queries.DocumentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;
using Api.Attributes;

namespace Api.Controllers
{
    [SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentItemController(IMediator mediator) : ControllerBase
    {
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
        //[HttpGet("[action]")]
        //public async Task<ActionResult<DocumentItemDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        //{
        //    if (companyId <= 0) return BadRequest("Company ID is required");

        //    return Ok(await mediator.Send(new GetDocumentByIdQuery(id, companyId)));
        //}

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentItemDto>> Create([FromBody] CreateDocumentItemRequest request)
        {
            return Ok(await mediator.Send(new AddDocumentItemCommand(request)));
        }
        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteDocumentItemCommand(id)));
        }
    }
}