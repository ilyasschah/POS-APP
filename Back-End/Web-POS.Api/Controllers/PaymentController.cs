using Api.Commands.PaymentCommands.Add;
using Api.Commands.PaymentCommands.ApplyCredit;
using Api.Commands.PaymentCommands.Delete;
using Api.Commands.PaymentCommands.Update;
using Api.Models;
using Api.Queries.PaymentQuery;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PaymentsController : ControllerBase
    {
        private readonly IMediator _mediator;

        public PaymentsController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<PaymentDto?>> GetById([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (id <= 0) return BadRequest(new { message = "Payment ID is required" });

            var result = await _mediator.Send(new GetPaymentByIdQuery(id, companyId), ct);
            return result == null ? NotFound(new { message = "Payment not found" }) : Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<IEnumerable<PaymentDto>>> GetByDocumentId([FromQuery] int documentId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (documentId <= 0) return BadRequest(new { message = "Document ID is required" });

            var result = await _mediator.Send(new GetPaymentsByDocumentIdQuery(documentId, companyId), ct);
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<IEnumerable<PaymentDto>>> GetUnreported([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            var result = await _mediator.Send(new GetUnreportedPaymentsQuery(companyId), ct);
            return Ok(result);
        }

        [Authorize]
        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreatePaymentRequest req, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await _mediator.Send(new AddPaymentCommand(req, companyId), ct);
                return Ok(new { message = "Payment added successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize]
        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdatePaymentRequest req, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var result = await _mediator.Send(new UpdatePaymentCommand(req, companyId), ct);
                return Ok(new { message = "Payment updated successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize]
        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (id <= 0) return BadRequest(new { message = "Payment ID is required" });

            try
            {
                var ok = await _mediator.Send(new DeletePaymentCommand(id, companyId), ct);
                return ok
                    ? Ok(new { message = "Payment deleted successfully" })
                    : NotFound(new { message = "Payment not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize]
        [HttpPost("[action]")]
        public async Task<IActionResult> ApplyCreditPayment(
            [FromBody] ApplyCreditPaymentRequest req,
            [FromQuery] int companyId,
            [FromQuery] int userId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (userId    <= 0) return BadRequest(new { message = "User ID is required" });

            try
            {
                var ok = await _mediator.Send(
                    new ApplyCreditPaymentCommand(req, companyId, userId), ct);
                return ok
                    ? Ok(new { message = "Credit payment applied successfully" })
                    : BadRequest(new { message = "No documents were updated" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}