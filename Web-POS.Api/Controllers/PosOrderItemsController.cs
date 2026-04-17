using Api.Attributes;
using Api.Commands.PosOrderItemCommand;
using Api.Commands.PosOrderItemCommands.Add;
using Api.Commands.PosOrderItemCommands.Delete;
using Api.Models;
using Api.Queries.PosOrderItemQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class PosOrderItemController : ControllerBase
    {
        private readonly IMediator _mediator;

        public PosOrderItemController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<IActionResult> GetByOrderId([FromQuery] int posOrderId, [FromQuery] int companyId)
        {
            if (posOrderId <= 0)
                return BadRequest(new { message = "Order ID must be provided." });

            var query = new GetPosOrderItemsByOrderIdQuery { PosOrderId = posOrderId, CompanyId = companyId };
            var result = await _mediator.Send(query);

            return Ok(result);
        }

        [HttpGet("[action]")]
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

        [HttpPost("[action]")]
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
        [HttpPost("[action]")]
        public async Task<IActionResult> BulkAdd([FromQuery] int companyId, [FromBody] List<BulkAddPosOrderItemRequest> requests)
        {
            if (companyId <= 0)
                return BadRequest(new { message = "Company ID is required." });

            if (requests == null || !requests.Any())
                return BadRequest(new { message = "Item list cannot be empty." });

            try
            {
                var command = new BulkAddPosOrderItemsCommand(companyId, requests);
                var result = await _mediator.Send(command);

                if (result)
                    return Ok(new { message = "Items successfully added to the order." });

                return BadRequest(new { message = "Failed to add items to the order." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An error occurred while saving the cart.", details = ex.Message });
            }
        }

        [HttpPatch("[action]")]
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

        [HttpDelete("[action]")]
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