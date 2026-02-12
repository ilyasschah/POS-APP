using Products.Api.Commands.PaymentCommands.Add;
using Products.Api.Commands.PaymentCommands.Delete;
using Products.Api.Commands.PaymentCommands.Update;
using Products.Api.Queries.PaymentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PaymentsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllPaymentsQuery { CompanyId = companyId }));
        }
        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PaymentDto>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPaymentByIdQuery { Id = id, CompanyId = companyId }));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<PaymentDto>> Add([FromBody] CreatePaymentRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var command = new AddPaymentCommand(request, companyId);

            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
        }
        [HttpPut("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] UpdatePaymentRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            return Ok(await mediator.Send(new UpdatePaymentCommand(id, request, companyId)));
        }
        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var result = await mediator.Send(new DeletePaymentCommand { Id = id, CompanyId = companyId });
            return Ok(new { Id = id, Message = "Payment deleted successfully" });
        }
    }
}