using Api.Commands.DocumentTypeCommands.Add;
//using Api.Commands.DocumentTypeCommands.Delete;
//using Api.Commands.DocumentTypeCommands.Update;
using Api.Queries.DocumentTypeQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;
using Api.Attributes;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentTypeController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentTypeDto>>> GetAll(CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new GetAllDocumentTypesQuery { }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentTypeDto>> GetById([FromQuery] int id, CancellationToken ct = default)
        {
            if (id == 0) return BadRequest("Document Type ID is required");
            return Ok(await mediator.Send(new GetDocumentTypeByIdQuery(id), ct));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<bool>> Create([FromBody] CreateDocumentTypeRequest request, CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new AddDocumentTypeCommand(request), ct));
        }
        //[HttpPut("[action]")]
        //public async Task<ActionResult<bool>> Update([FromQuery] int id, [FromQuery] UpdateDocumentTypeRequest request, CancellationToken ct = default)
        //{
        //    return Ok(await mediator.Send(new UpdateDocumentTypeCommand(id, request), ct));
        //}

        //[HttpDelete("[action]/{id}")]
        //public async Task<IActionResult> Delete(int id, CancellationToken ct = default)
        //{
        //    return Ok(await mediator.Send(new DeleteDocumentTypeCommand(id), ct));
        //}
    }
}
