using Api.Commands.DocumentsCommands.Add;
using Api.Commands.DocumentsCommands.Delete;
using Api.Commands.DocumentsCommands.Update;
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
    public class DocumentController (IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0)
                return BadRequest("Company ID is required");

            return Ok(await mediator.Send(new GetAllDocumentsQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<DocumentDto?>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId == 0)
                return BadRequest("Company ID is required");

            return Ok(await mediator.Send(new GetDocumentByIdQuery(id) { CompanyId = companyId }));
        }

        [HttpGet("[action]/{number}")]
        public async Task<ActionResult<DocumentDto>> GetByNumber(string number, [FromQuery] int companyId)
        {
            if (companyId == 0)
                return BadRequest("Company ID is required");

            return Ok(await mediator.Send(new GetDocumentByNumberQuery(number) { CompanyId = companyId }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentDto>> Add(
            [FromBody] CreateDocumentRequest req,
            [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var command = new AddDocumentCommand(req, companyId);

            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(
            int id,
            [FromBody] UpdateDocumentRequest req,
            [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var ok = await mediator.Send(new UpdateDocumentCommand(req, companyId));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var ok = await mediator.Send(new DeleteDocumentCommand(id, companyId));
            return ok ? NoContent() : NotFound();
        }
    }
}
