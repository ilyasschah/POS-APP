using Microsoft.AspNetCore.Mvc;
using MediatR;
using Api.Models;
using Api.Queries.PosOrderQuery;
using Api.Commands.PosOrderCommand;
using Api.Attributes;

namespace Api.Controllers
{
    [SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class PosOrderController : ControllerBase
    {
        private readonly IMediator _mediator;

        public PosOrderController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<IActionResult> GetAll([FromQuery] int companyId)
        {
            if (companyId <= 0)
                return BadRequest("Company ID must be provided.");

            var query = new GetAllPosOrdersQuery { CompanyId = companyId };
            var result = await _mediator.Send(query);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<IActionResult> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0)
                return BadRequest("Company ID must be provided.");

            var query = new GetPosOrderByIdQuery { Id = id, CompanyId = companyId };
            var result = await _mediator.Send(query);

            if (result == null)
                return NotFound($"PosOrder with ID {id} not found.");

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<IActionResult> GetByNumber([FromQuery]  string number, [FromQuery] int companyId)
        {
            var query = new GetPosOrderByNumberQuery { Number = number, CompanyId = companyId };
            var result = await _mediator.Send(query);

            if (result == null)
                return NotFound($"PosOrder with Number {number} not found.");

            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Create( [FromBody] CreatePosOrderRequest request,[FromQuery] int companyId)
        {
            if (companyId <= 0)
                return BadRequest("Company ID must be provided.");

            try
            {
                var command = new CreatePosOrderCommand(companyId, request);
                var result = await _mediator.Send(command);

                return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId = companyId }, result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdatePosOrderRequest request, [FromQuery] int companyId)
        {
            try
            {
                var command = new UpdatePosOrderCommand(request,companyId);
                var success = await _mediator.Send(command);

                if (!success)
                    return NotFound($"PosOrder with ID {request.Id} not found.");
                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id)
        {
            var command = new DeletePosOrderCommand(id);
            var success = await _mediator.Send(command);

            if (!success)
                return NotFound($"PosOrder with ID {id} not found.");

            return NoContent();
        }
    }
}