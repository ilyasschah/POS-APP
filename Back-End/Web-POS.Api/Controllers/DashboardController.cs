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
        public async Task<ActionResult<DashboardDataDto>> GetDashboardData([FromQuery] int companyId, [FromQuery] DateTime startDate, [FromQuery] DateTime endDate, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required.");
            if (startDate > endDate) return BadRequest("Start date cannot be after end date.");

            var query = new GetDashboardDataQuery(companyId, startDate, endDate);
            var result = await _mediator.Send(query, ct);

            return Ok(result);
        }
    }
}