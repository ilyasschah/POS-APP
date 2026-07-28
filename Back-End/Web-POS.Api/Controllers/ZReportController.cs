using Api.Commands.ZReportCommands.Add;
using Api.Queries.ZReportQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ZReportsController : ControllerBase
    {
        private readonly IMediator _mediator;

        public ZReportsController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("GetById")]
        public async Task<IActionResult> GetById([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new GetZReportByIdQuery(id, companyId), ct);
            if (result == null) return NotFound("Z-Report not found.");
            return Ok(result);
        }

        [HttpGet("GetAll")]
        public async Task<IActionResult> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new GetAllZReportsQuery(companyId), ct);
            return Ok(result);
        }

        [HttpGet("GetLast")]
        public async Task<IActionResult> GetLast([FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new GetLastZReportQuery(companyId), ct);
            if (result == null) return NotFound("No Z-Reports found for this company.");
            return Ok(result);
        }

        [HttpPost("Generate")]
        public async Task<IActionResult> Generate([FromQuery] int companyId, [FromQuery] int userId, CancellationToken ct = default)
        {
            try
            {
                var result = await _mediator.Send(new GenerateZReportCommand(companyId, userId), ct);
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}