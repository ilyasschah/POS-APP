using Api.Commands.PosOrderItemCommand;
using Api.Commands.PosOrderItemCommands.Delete;
using Api.Models;
using Api.Queries.PosOrderItemQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PosOrderItemController : ControllerBase
    {
        private readonly IMediator _mediator;

        public PosOrderItemController(IMediator mediator)
        {
            _mediator = mediator;
        }

        // GET: api/PosOrderItem/Order?posOrderId=1
        [HttpGet("Order")]
        public async Task<IActionResult> GetByOrderId([FromQuery] int posOrderId)
        {
            if (posOrderId <= 0)
                return BadRequest(new { message = "Order ID must be provided." });

            var query = new GetPosOrderItemsByOrderIdQuery { PosOrderId = posOrderId };
            var result = await _mediator.Send(query);

            return Ok(result);
        }

        // GET: api/PosOrderItem?id=5&companyId=2
        [HttpGet]
        public async Task<IActionResult> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (id <= 0 || companyId <= 0)
                return BadRequest(new { message = "Both Item ID and Company ID must be provided." });

            var query = new GetPosOrderItemByIdQuery { Id = id, CompanyId = companyId };
            var result = await _mediator.Send(query);

            if (result == null)
                return NotFound(new { message = $"Order Item with ID {id} not found." });

            return Ok(result);
        }

        // POST: api/PosOrderItem?companyId=2
        [HttpPost]
        public async Task<IActionResult> Create([FromQuery] int companyId, [FromBody] CreatePosOrderItemRequest request)
        {
            if (companyId <= 0)
                return BadRequest(new { message = "Company ID must be provided." });

            try
            {
                var command = new CreatePosOrderItemCommand(companyId, request);
                var result = await _mediator.Send(command);

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // PATCH: api/PosOrderItem?companyId=2
        [HttpPatch]
        public async Task<IActionResult> Update([FromQuery] int companyId, [FromBody] UpdatePosOrderItemRequest request)
        {
            if (companyId <= 0)
                return BadRequest(new { message = "Company ID must be provided." });

            try
            {
                var command = new UpdatePosOrderItemCommand( companyId, request);
                var success = await _mediator.Send(command);

                if (!success)
                    return NotFound(new { message = $"Order Item with ID {request.Id} not found." });

                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // DELETE: api/PosOrderItem?id=5&companyId=2
        [HttpDelete]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (id <= 0 || companyId <= 0)
                return BadRequest(new { message = "Both Item ID and Company ID must be provided." });

            try
            {
                var command = new DeletePosOrderItemCommand(id, companyId);
                var success = await _mediator.Send(command);

                if (!success)
                    return NotFound(new { message = $"Order Item with ID {id} not found." });

                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}