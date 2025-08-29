using Documents.Api.Commands.DocumentTypeCommands.Add;
using Documents.Api.Commands.DocumentTypeCommands.Delete;
using Documents.Api.Commands.DocumentTypeCommands.Update;
using Documents.Api.Models.DocumentTypes;
using Documents.Api.Queries.DocumentTypeQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Documents.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentTypeController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentTypeDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllDocumentTypesQuery()));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentTypeDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetDocumentTypeByIdQuery(id)));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<bool>> Create([FromQuery] CreateDocumentTypeRequest request)
        {
            return Ok(await mediator.Send(new AddDocumentTypeCommand(request)));
        }

        [HttpPut("[action]")]
        public async Task<ActionResult<bool>> Update([FromQuery] int id, [FromQuery] UpdateDocumentTypeRequest request)
        {
            return Ok(await mediator.Send(new UpdateDocumentTypeCommand(id, request)));
        }

        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteDocumentTypeCommand(id)));
        }
    }
}
