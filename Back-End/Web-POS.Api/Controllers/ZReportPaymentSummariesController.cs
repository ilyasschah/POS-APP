using Api.Models;
using Api.Queries.ZReportPaymentSummaryQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ZReportPaymentSummariesController(IMediator mediator) : ControllerBase
    {
        /// <summary>All Z-report payment summaries for a company (offline mirror pull).</summary>
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ZReportPaymentSummaryDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            return Ok(await mediator.Send(new GetAllZReportPaymentSummariesQuery(companyId)));
        }
    }
}
