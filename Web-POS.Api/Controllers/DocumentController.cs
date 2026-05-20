using Api.Commands.DocumentsCommands.Add;
using Api.Commands.DocumentsCommands.Delete;
using Api.Commands.DocumentsCommands.Update;
using Api.Commands.RefundCommands;
using Api.Queries.DocumentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;
using Api.Attributes;
using Api.DataBase;
using Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentController(IMediator mediator, AppDbContext db) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<string>> GetNextNumber(
            [FromQuery] int companyId,
            [FromQuery] int documentTypeId)
        {
            if (companyId <= 0)       return BadRequest("Company ID is required");
            if (documentTypeId <= 0)  return BadRequest("Document type ID is required");

            var docType = await db.DocumentTypes
                .AsNoTracking()
                .FirstOrDefaultAsync(t => t.Id == documentTypeId);

            if (docType == null) return BadRequest("Invalid document type");

            string yy = DateTime.UtcNow.ToString("yy");
            string counterKey = $"DOC_{yy}_{docType.Code}_{companyId}";

            var counter = await db.DocumentsCounter
                .FirstOrDefaultAsync(c => c.Name.ToLower() == counterKey.ToLower());

            int next;
            if (counter == null)
            {
                next = 1;
                db.DocumentsCounter.Add(DocumentsCounter.Create(counterKey, next, companyId));
            }
            else
            {
                next = counter.Value + 1;
                counter.UpdateValue(next);
            }
            await db.SaveChangesAsync();

            return Ok($"{yy}-{docType.Code}-{next.ToString().PadLeft(6, '0')}");
        }


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
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await mediator.Send(new AddDocumentCommand(req, companyId));
                return Ok(new { message = "Document created", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
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

        [HttpPost("[action]")]
        public async Task<IActionResult> Refund(
            [FromBody] ProcessRefundRequest req,
            [FromQuery] int companyId,
            [FromQuery] int userId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (userId <= 0)    return BadRequest(new { message = "User ID is required" });

            try
            {
                var result = await mediator.Send(new ProcessRefundCommand
                {
                    CompanyId = companyId,
                    UserId    = userId,
                    Request   = req,
                });
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
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