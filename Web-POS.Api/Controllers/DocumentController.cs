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
    public class DocumentController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            return Ok(await mediator.Send(new GetAllDocumentsQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentDto?>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            return Ok(await mediator.Send(new GetDocumentByIdQuery { Id = id, CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentDto?>> GetByNumber([FromQuery] string number, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            return Ok(await mediator.Send(new GetDocumentByNumberQuery { Number = number, CompanyId = companyId }));
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreateDocumentRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            var result = await mediator.Send(new AddDocumentCommand(req, companyId));

            return result
                ? Ok(new { Message = "Document created" })
                : BadRequest(new { Message = "Failed to create document" });
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateDocumentRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            var result = await mediator.Send(new UpdateDocumentCommand(req, companyId));

            return result
                ? Ok(new { Message = "Document updated" })
                : BadRequest(new { Message = "Failed to update document" });
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            var result = await mediator.Send(new DeleteDocumentCommand(id, companyId));

            return result
                ? Ok(new { Message = "Document deleted" })
                : BadRequest(new { Message = "Failed to delete document" });
        }
    }
}