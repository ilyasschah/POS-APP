using Microsoft.AspNetCore.Mvc;
using MediatR;
using Api.Commands.Dashboard;
using Api.Attributes;

namespace Api.Controllers
{
    [SwaggerVisible]
    [ApiController]
    [Route("api/[controller]")]
    public class DashboardController : ControllerBase
    {
        private readonly IMediator _mediator;

        public DashboardController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        /// <param name="tzOffsetMinutes">
        /// Caller's offset from UTC in minutes (e.g. 60 for UTC+1), so Hourly
        /// Peak Times comes back in local time. Optional: omitting it keeps the
        /// legacy UTC buckets.
        /// </param>
        public async Task<ActionResult<DashboardDataDto>> GetDashboardData([FromQuery] int companyId, [FromQuery] DateTime startDate, [FromQuery] DateTime endDate, [FromQuery] int tzOffsetMinutes = 0, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required.");
            if (startDate > endDate) return BadRequest("Start date cannot be after end date.");

            var query = new GetDashboardDataQuery(companyId, startDate, endDate, tzOffsetMinutes);
            var result = await _mediator.Send(query, ct);

            return Ok(result);
        }
    }
}