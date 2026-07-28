using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;
using Api.Attributes;
using Api.Commands.DocumentItemCommands.Add;
using Api.Commands.DocumentItemCommands.Update;
using Api.Commands.DocumentItemCommands.Delete;
using Api.Queries.DocumentItemQuery;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentItemsController : ControllerBase
    {
        private readonly IMediator _mediator;

        public DocumentItemsController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentItemDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetAllDocumentItemQuery { CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentItemDto>> GetById([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetDocumentItemsByIdQuery { Id = id, CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentItemDto>>> GetByDocumentId([FromQuery] int documentId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            if (documentId <= 0) return BadRequest("Document ID is required");

            return Ok(await _mediator.Send(new GetDocumentItemsByDocumentIdQuery { DocumentId = documentId, CompanyId = companyId }, ct));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentItemDto>> Add([FromBody] CreateDocumentItemRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new AddDocumentItemCommand(request, companyId), ct);
            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateDocumentItemRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new UpdateDocumentItemCommand(request, companyId), ct);
            return Ok(new { Success = result });
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new DeleteDocumentItemCommand(id, companyId), ct);
            return Ok(new { Message = result ? "Item deleted successfully" : "Failed to delete item" });
        }
    }
}