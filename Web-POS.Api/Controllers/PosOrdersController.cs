using Api.Attributes;
using Api.Commands.PosOrderCommands;
using Api.Commands.PosOrderCommands.Add;
using Api.Commands.PosOrderCommands.BatchSync;
using Api.Commands.PosOrderCommands.Delete;
using Api.Commands.PosOrderCommands.Update;
using Api.Commands.PosOrderCommands.Void;
using Api.Constants;
using Api.Models;
using Api.Queries.PosOrderQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    //[SwaggerVisible]
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

            if (request.WarehouseId <= 0)
                return BadRequest("Warehouse ID is required for inventory tracking.");

            try
            {
                var command = new CreatePosOrderCommand( request, companyId);
                var result = await _mediator.Send(command);

                return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId = companyId }, result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
        [HttpPost("Checkout")]
        public async Task<IActionResult> Checkout([FromQuery] int companyId, [FromQuery] int userId, [FromBody] CheckoutPosOrderRequest request)
        {
            if (companyId <= 0 || userId <= 0)
                return BadRequest(new { message = "Company ID and User ID are required." });

            try
            {
                var command = new CheckoutPosOrderCommand(companyId, userId, request);
                var documentId = await _mediator.Send(command);

                return Ok(new { message = "Payment successful! Order converted to Document.", documentId });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Checkout failed.", details = ex.Message });
            }
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdatePosOrderRequest request, [FromQuery] int companyId)
        {
            if (companyId <= 0)
                return BadRequest("Company ID must be provided.");

            if (request.WarehouseId <= 0)
                return BadRequest("Warehouse ID is required for inventory tracking.");

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
        [HttpPatch("UpdateStatus")]
        public async Task<IActionResult> UpdateStatus([FromQuery] int companyId, [FromBody] UpdatePosOrderStatusRequest req)
        {
            try
            {
                var command = new UpdatePosOrderStatusCommand(companyId, req);
                var success = await _mediator.Send(command);
                if (!success)
                    return NotFound($"PosOrder with ID {req.Id} not found.");
                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }
        [HttpPost("Void")]
        public async Task<IActionResult> Void(
            [FromQuery] int posOrderId,
            [FromQuery] int companyId,
            [FromQuery] int warehouseId,
            [FromQuery] int documentTypeId = DocumentTypeConstants.Sales)
        {
            if (companyId <= 0 || posOrderId <= 0 || warehouseId <= 0)
                return BadRequest(new { message = "Company ID, Order ID, and Warehouse ID are required." });

            try
            {
                var command = new VoidPosOrderCommand(posOrderId, companyId, warehouseId, documentTypeId);
                var success = await _mediator.Send(command);

                if (!success)
                    return NotFound(new { message = $"PosOrder with ID {posOrderId} not found." });

                return Ok(new { message = "Order voided successfully." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Void failed.", details = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, [FromQuery] int warehouseId)
        {
            var command = new DeletePosOrderCommand(id, companyId, warehouseId);
            var success = await _mediator.Send(command);

            if (!success)
                return NotFound(new
                {
                    message = $"PosOrder with ID {id} and CompanyId {companyId} was not found."
                });

            return Ok(new
            {
                message = $"PosOrder with ID {id} was deleted successfully."
            });
        }
        [HttpPost("BatchSync")]
        public async Task<ActionResult<BatchSyncPosOrdersResponse>> BatchSync(
            [FromQuery] int companyId,
            [FromBody] BatchSyncPosOrdersRequest request)
        {
            if (companyId <= 0)
                return BadRequest(new { message = "Company ID is required." });

            if (request?.Orders is null || request.Orders.Count == 0)
                return BadRequest(new { message = "Batch contains no orders." });

            // Always returns 200 — partial failures are encoded inside the results array.
            // The client inspects each result.Success individually.
            var result = await _mediator.Send(new BatchSyncPosOrdersCommand(request, companyId));
            return Ok(result);
        }

        [HttpGet("GetKitchenOrders")]
        public async Task<IActionResult> GetKitchenOrders([FromQuery] int companyId)
        {
            if (companyId <= 0)
                return BadRequest("Company ID must be provided.");

            var query = new GetKitchenOrdersQuery { CompanyId = companyId };
            var result = await _mediator.Send(query);

            return Ok(result);
        }
    }
}