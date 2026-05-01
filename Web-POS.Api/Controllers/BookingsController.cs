using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.BookingCommands.Add;
using Api.Commands.BookingCommands.UpdateStatus;
using Api.Commands.BookingCommands.UpdateResource;
using Api.Commands.BookingCommands.Delete;
using Api.Queries.BookingQuery.Get;
using Api.Models;
using Api.Attributes;
namespace Api.Controllers
{
    [SwaggerVisible ]
    [Route("api/[controller]")]
    [ApiController]
    public class BookingsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<BookingDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllBookingsQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<BookingDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (id == 0) return BadRequest("Booking ID is required");
            var result = await mediator.Send(new GetBookingByIdQuery { Id = id, CompanyId = companyId });
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<BookingDto>> Add([FromBody] CreateBookingRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new AddBookingCommand(request, companyId));
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult> UpdateStatus([FromBody] UpdateBookingStatusRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (request.BookingId == 0) return BadRequest("Booking ID is required");
            var success = await mediator.Send(new UpdateBookingStatusCommand(request, companyId));
            if (!success) return NotFound();
            return Ok(new { Message = "Booking status updated" });
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult> UpdateResource([FromBody] UpdateBookingResourceRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (request.BookingId == 0) return BadRequest("Booking ID is required");
            var success = await mediator.Send(new UpdateBookingResourceCommand(request, companyId));
            if (!success) return NotFound();
            return Ok(new { Message = "Booking resource updated" });
        }
        [HttpPatch("[action]")]
        public async Task<ActionResult> LinkPosOrder([FromQuery] int companyId, [FromQuery] int bookingId, [FromQuery] int posOrderId)
        {
            if (companyId == 0 || bookingId == 0 || posOrderId == 0)
                return BadRequest("Invalid parameters");

            var success = await mediator.Send(new LinkPosOrderCommand(companyId, bookingId, posOrderId));

            if (!success) return NotFound("Booking not found");

            return Ok(new { Message = "Order Linked to Booking" });
        }
        [HttpDelete("[action]")]
        public async Task<ActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, [FromQuery] int  warehouseid)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (id == 0) return BadRequest("Booking ID is required");
            var success = await mediator.Send(new DeleteBookingCommand(id, companyId, warehouseid));
            if (!success) return NotFound();
            return Ok(new { Id = id, Message = "Booking deleted" });
        }
    }
}
