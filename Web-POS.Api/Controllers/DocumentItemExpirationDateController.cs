using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.DocumentItemExpirationDateCommands.Add;
using Api.Commands.DocumentItemExpirationDateCommands.Update;
using Api.Commands.DocumentItemExpirationDateCommands.Delete;
using Api.Queries.DocumentItemExpirationDateQuery.Get;
using Api.Models;

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
        public async Task<ActionResult<DocumentItemExpirationDateDto?>> Get([FromQuery] int documentItemId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentItemId <= 0) return BadRequest(new { message = "Document Item ID is required" });

            var result = await _mediator.Send(new GetDocumentItemExpirationDateQuery(documentItemId, companyId));
            return result == null ? NotFound(new { message = "Expiration date not found for this document item" }) : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreateDocumentItemExpirationDateRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await _mediator.Send(new AddDocumentItemExpirationDateCommand(req, companyId));
                return Ok(new { message = "Expiration date added successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateDocumentItemExpirationDateRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await _mediator.Send(new UpdateDocumentItemExpirationDateCommand(req, companyId));
                return Ok(new { message = "Expiration date updated successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int documentItemId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentItemId <= 0) return BadRequest(new { message = "Document Item ID is required" });

            try
            {
                var ok = await _mediator.Send(new DeleteDocumentItemExpirationDateCommand(documentItemId, companyId));
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