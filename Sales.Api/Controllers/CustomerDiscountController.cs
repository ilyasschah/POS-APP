using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.CustomerCommands.Add;
using Sales.Api.Models;
using Sales.Api.Queries.CustomerQuery.Get;

namespace Sales.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CustomerDiscountController (IMediator mediator) : ControllerBase
    {

        [HttpGet("[action]")]
        public async Task<ActionResult<List<CustomerDiscountDto>>> GetAllCustomerDiscounts()
        {
            return Ok(await mediator.Send(new GetAllCustomersDiscountQuery()));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<CustomerDiscountDto>> AddCustomerDiscount([FromBody] CreateCustomerDiscountRequest createcustomerdiscountRequest)
        {
            return Ok(await mediator.Send(new AddCustomerDiscountCommand(createcustomerdiscountRequest)));
        }
    }
}
