using Api.Commands.CustomerDiscountCommands;
using Api.Models;
using Api.Queries.CustomerDiscountQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class CustomerDiscountsController : ControllerBase
    {
        private readonly IMediator _mediator;

        public CustomerDiscountsController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("GetAll")]
        public async Task<IActionResult> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new GetAllCustomerDiscountsQuery { CompanyId = companyId }, ct);
            return Ok(result);
        }

        [HttpGet("GetByCustomerId")]
        public async Task<IActionResult> GetByCustomerId([FromQuery] int customerId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new GetCustomerDiscountByCustomerIdQuery { CustomerId = customerId, CompanyId = companyId }, ct);
            if (result == null) return Ok(null);
            return Ok(result);
        }

        [HttpPost("Add")]
        public async Task<IActionResult> Add([FromQuery] int companyId, [FromBody] CreateCustomerDiscountRequest req, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new CreateCustomerDiscountCommand(companyId, req), ct);
            return Ok(result);
        }

        [HttpPatch("Update")]
        public async Task<IActionResult> Update([FromQuery] int companyId, [FromBody] UpdateCustomerDiscountRequest req, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new UpdateCustomerDiscountCommand(companyId, req), ct);
            return Ok(result);
        }

        [HttpDelete("Delete")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            var result = await _mediator.Send(new DeleteCustomerDiscountCommand(id, companyId), ct);
            return Ok(result);
        }
    }
}