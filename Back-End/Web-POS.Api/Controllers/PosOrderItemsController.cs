using Api.Attributes;
using Api.Commands.PosOrderItemCommands.Add;
using Api.Commands.PosOrderItemCommands.Delete;
using Api.Commands.PosOrderItemCommands.Update;
using Api.Models;
using Api.Queries.PosOrderItemQuery;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    //[SwaggerVisible]
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
        public async Task<IActionResult> GetByOrderId([FromQuery] int posOrderId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (posOrderId <= 0)
                return BadRequest(new { message = "Order ID must be provided." });

            var query = new GetPosOrderItemsByOrderIdQuery { PosOrderId = posOrderId, CompanyId = companyId };
            var result = await _mediator.Send(query, ct);

            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<IActionResult> GetById([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (id <= 0 || companyId <= 0)
                return BadRequest(new { message = "Both Item ID and Company ID must be provided." });

            var query = new GetPosOrderItemByIdQuery { Id = id, CompanyId = companyId };
            var result = await _mediator.Send(query, ct);

            if (result == null)
                return NotFound(new { message = $"Order Item with ID {id} not found." });

            return Ok(result);
        }

        [Authorize]
        [HttpPost("[action]")]
        public async Task<IActionResult> Create([FromQuery] int companyId, [FromBody] CreatePosOrderItemRequest request, CancellationToken ct = default)
        {
            if (companyId <= 0)
                return BadRequest(new { message = "Company ID must be provided." });

            try
            {
                var command = new CreatePosOrderItemCommand(companyId, request);
                var result = await _mediator.Send(command, ct);

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
        [Authorize]
        [HttpPost("[action]")]
        public async Task<IActionResult> BulkAdd([FromQuery] int companyId, [FromQuery] int warehouseId, [FromQuery] decimal orderTotal, [FromBody] List<BulkAddPosOrderItemRequest> requests, [FromQuery] bool allowNegativeStock = false, CancellationToken ct = default)
        {
            if (companyId <= 0)
                return BadRequest(new { message = "Company ID is required." });

            if (warehouseId <= 0)
                return BadRequest(new { message = "Warehouse ID is required." });

            if (requests == null || !requests.Any())
                return BadRequest(new { message = "Item list cannot be empty." });

            try
            {
                // allowNegativeStock is set true by offline sync replays (a parked
                // order whose cart-time stock guard already ran) so the post isn't
                // re-blocked here. The live cashier path leaves it false/default.
                var command = new BulkAddPosOrderItemsCommand(companyId, warehouseId, orderTotal, requests, allowNegativeStock);
                var result = await _mediator.Send(command, ct);

                if (result.Success)
                    return Ok(result);

                return BadRequest(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An error occurred while saving the cart.", details = ex.Message });
            }
        }

        [Authorize]
        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromQuery] int companyId, [FromBody] UpdatePosOrderItemRequest request, CancellationToken ct = default)
        {
            if (companyId <= 0)
                return BadRequest(new { message = "Company ID must be provided." });

            try
            {
                var command = new UpdatePosOrderItemCommand( companyId, request);
                var success = await _mediator.Send(command, ct);

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

        [Authorize]
        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (id <= 0 || companyId <= 0)
                return BadRequest(new { message = "Both Item ID and Company ID must be provided." });

            try
            {
                var command = new DeletePosOrderItemCommand(id, companyId);
                var success = await _mediator.Send(command, ct);

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