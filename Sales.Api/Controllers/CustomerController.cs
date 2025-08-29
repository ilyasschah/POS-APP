using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.CustomerCommands.Add;
using Sales.Api.Models;
using Sales.Api.Queries.CustomerQuery.Get;

namespace Sales.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CustomerController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CustomerDto>>> GetAllCustomers()
        {
            return Ok (await mediator.Send(new GetAllCustomersQuery()));
            
        }
        //POST: api/barcodes
        [HttpPost("[action]")]
        public async Task<ActionResult<CustomerDto>> AddCustomercommand([FromBody] CreateCustomerRequest createrequest)
        {
            return Ok(await mediator.Send(new AddCustomerCommand(createrequest)));
        }
    }
}
