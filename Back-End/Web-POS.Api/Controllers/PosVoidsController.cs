using Api.Commands.PosVoidCommands.Add;
using Api.Commands.PosVoidCommands.Update;
using Api.Models;
using Api.Queries.PosVoidQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using System;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PosVoidsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllPosVoidsQuery { CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<PosVoidDto?>> GetById(int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPosVoidByIdQuery { Id = id, CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetByOrderNumber(string orderNumber, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPosVoidsByOrderNumberQuery(orderNumber) { CompanyId = companyId }, ct));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosVoidDto>> Add([FromQuery] CreatePosVoidRequest request, CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new AddPosVoidCommand(request), ct));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetByDateRange(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? userId = null,
            [FromQuery] int? productId = null, CancellationToken ct = default)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var req = new GetPosVoidsByDateRangeRequest
            {
                CompanyId = companyId,
                StartDate = startDate,
                EndDate   = endDate,
                UserId    = userId,
                ProductId = productId
            };
            return Ok(await mediator.Send(new GetPosVoidsByDateRangeQuery { Request = req }, ct));
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Update([FromQuery] UpdatePosVoidRequest request, CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new UpdatePosVoidCommand(request), ct));
        }
        //[HttpDelete("Delete/{id}")]
        //public async Task<IActionResult> Delete(string reason, CancellationToken ct = default)
        //{
        //    return Ok(await mediator.Send(new DeletePosVoidCommand(reason), ct));
        //}
    }
}