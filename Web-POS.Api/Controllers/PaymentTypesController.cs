using Api.Commands.PaymentTypeCommands.Add;
using Api.Commands.PaymentTypeCommands.Delete;
using Api.Commands.PaymentTypeCommands.Update;
using Api.Queries.PaymentTypeQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;
using Api.Models;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [ApiController]
    [Route("api/[controller]")]
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
            var result = await mediator.Send(new AddPaymentTypeCommand(req, companyId));
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> Update([FromBody] UpdatePaymentTypeRequest req, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new UpdatePaymentTypeCommand(req, companyId));
            return Ok(new { Message = result ? "Payment type updated successfully" : "Failed to update payment type" });
        }

        [HttpDelete("[action]")]
        public async Task<ActionResult<PaymentTypeDto>> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new DeletePaymentTypeCommand(id, companyId));
            return Ok(new { Message = result ? "Payment type deleted successfully" : "Failed to delete payment type" });
        }
    }
}