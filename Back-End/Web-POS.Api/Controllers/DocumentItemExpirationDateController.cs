using Api.Commands.DocumentItemExpirationDateCommands.Add;
using Api.Commands.DocumentItemExpirationDateCommands.Delete;
using Api.Commands.DocumentItemExpirationDateCommands.Update;
using Api.Models;
using Api.Queries.DocumentItemExpirationDateQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentItemExpirationDatesController : ControllerBase
    {
        private readonly IMediator _mediator;

        public DocumentItemExpirationDatesController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentItemExpirationDateDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            return Ok(await _mediator.Send(new GetAllDocumentItemExpirationDatesQuery(companyId), ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentItemExpirationDateDto?>> Get([FromQuery] int documentItemId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentItemId <= 0) return BadRequest(new { message = "Document Item ID is required" });

            var result = await _mediator.Send(new GetDocumentItemExpirationDateQuery(documentItemId, companyId), ct);
            return result == null ? NotFound(new { message = "Expiration date not found for this document item" }) : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreateDocumentItemExpirationDateRequest req, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await _mediator.Send(new AddDocumentItemExpirationDateCommand(req, companyId), ct);
                return Ok(new { message = "Expiration date added successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateDocumentItemExpirationDateRequest req, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await _mediator.Send(new UpdateDocumentItemExpirationDateCommand(req, companyId), ct);
                return Ok(new { message = "Expiration date updated successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int documentItemId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentItemId <= 0) return BadRequest(new { message = "Document Item ID is required" });

            try
            {
                var ok = await _mediator.Send(new DeleteDocumentItemExpirationDateCommand(documentItemId, companyId), ct);
                return ok
                    ? Ok(new { message = "Expiration date removed successfully" })
                    : NotFound(new { message = "Expiration date not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}