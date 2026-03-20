using Products.Api.Commands.PaymentTypeCommands.Add;
using Products.Api.Commands.PaymentTypeCommands.Delete;
using Products.Api.Commands.PaymentTypeCommands.Update;
using Products.Api.Queries.PaymentTypeQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PaymentTypesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PaymentTypeDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllPaymentTypesQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPaymentTypeByIdQuery { Id = id, CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> GetByName(string name, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetPaymentTypeByNameQuery { Name = name, CompanyId = companyId });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> Add([FromBody] CreatePaymentTypeRequest req, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var command = new AddPaymentTypeCommand(req, companyId);

            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> Update([FromBody] UpdatePaymentTypeRequest req, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var command = new UpdatePaymentTypeCommand(req, companyId);
            var result = await mediator.Send(command);
            return Ok(new { Id = req.Id, Message = "Payment type updated" });
        }

        [HttpDelete("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> Delete([FromBody] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new DeletePaymentTypeCommand(id, companyId));
            return Ok(new { Id = id, Message = "Payment type deleted" });
        }
    }
}