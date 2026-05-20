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
        public async Task<ActionResult<List<PosVoidDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllPosVoidsQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<PosVoidDto?>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPosVoidByIdQuery { Id = id, CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetByOrderNumber(string orderNumber, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPosVoidsByOrderNumberQuery(orderNumber) { CompanyId = companyId }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosVoidDto>> Add([FromQuery] CreatePosVoidRequest request)
        {
            return Ok(await mediator.Send(new AddPosVoidCommand(request)));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetByDateRange(
            [FromQuery] int companyId,
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] int? userId = null,
            [FromQuery] int? productId = null)
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
            return Ok(await mediator.Send(new GetPosVoidsByDateRangeQuery { Request = req }));
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Update([FromQuery] UpdatePosVoidRequest request)
        {
            return Ok(await mediator.Send(new UpdatePosVoidCommand(request)));
        }
        //[HttpDelete("Delete/{id}")]
        //public async Task<IActionResult> Delete(string reason)
        //{
        //    return Ok(await mediator.Send(new DeletePosVoidCommand(reason)));
        //}
    }
}