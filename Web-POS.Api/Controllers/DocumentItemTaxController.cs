using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.DocumentItemTaxCommands.Add;
using Api.Commands.DocumentItemTaxCommands.Update;
using Api.Commands.DocumentItemTaxCommands.Delete;
using Api.Queries.DocumentItemTaxQuery.Get;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentItemTaxesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentItemTaxDto>>> GetByDocumentItemId([FromQuery] int documentItemId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentItemId <= 0) return BadRequest(new { message = "Document Item ID is required" });

            var result = await mediator.Send(new GetDocumentItemTaxesByDocumentItemIdQuery(documentItemId, companyId));
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentItemTaxDto?>> GetByIds([FromQuery] int documentItemId, [FromQuery] int taxId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentItemId <= 0) return BadRequest(new { message = "Document Item ID is required" });
            if (taxId <= 0) return BadRequest(new { message = "Tax ID is required" });

            var result = await mediator.Send(new GetDocumentItemTaxByIdsQuery(documentItemId, taxId, companyId));
            return result is null ? NotFound(new { message = "Document item tax not found" }) : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreateDocumentItemTaxRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await mediator.Send(new AddDocumentItemTaxCommand(req, companyId));
                return Ok(new { message = "Tax applied to document item successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateDocumentItemTaxRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await mediator.Send(new UpdateDocumentItemTaxCommand(req, companyId));
                return Ok(new { message = "Document item tax updated successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int documentItemId, [FromQuery] int taxId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentItemId <= 0) return BadRequest(new { message = "Document Item ID is required" });
            if (taxId <= 0) return BadRequest(new { message = "Tax ID is required" });

            try
            {
                var ok = await mediator.Send(new DeleteDocumentItemTaxCommand(documentItemId, taxId, companyId));
                return ok
                    ? Ok(new { message = "Tax removed from document item successfully" })
                    : NotFound(new { message = "Document item tax not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}