using Api.DataBase;
using Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DiscountLinesController(AppDbContext db) : ControllerBase
    {
        /// Returns every DiscountLine for the company so clients can mirror the
        /// breakdown of sales made on other devices. Read-only — discount lines
        /// are created during checkout, never edited.
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DiscountLinePullDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            var rows = await db.DiscountLines
                .AsNoTracking()
                .Where(d => d.CompanyId == companyId)
                .Select(d => new DiscountLinePullDto
                {
                    Id          = d.Id,
                    CompanyId   = d.CompanyId,
                    DocumentId  = d.DocumentId,
                    ProductId   = d.ProductId,
                    Source      = d.Source,
                    SourceRefId = d.SourceRefId,
                    Value       = d.Value,
                    ValueType   = d.ValueType,
                    Amount      = d.Amount,
                    Sequence    = d.Sequence,
                    Label       = d.Label,
                })
                .ToListAsync();

            return Ok(rows);
        }
    }
}
