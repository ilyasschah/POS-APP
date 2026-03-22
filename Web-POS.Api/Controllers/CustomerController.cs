using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.CustomerCommands.Add;
using Api.Queries.CustomerQuery.Get;
using Api.Commands.CustomerCommands.Update;
using Api.Commands.CustomerCommands.Delete;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CustomerController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CustomerDto>>> GetAllCustomers([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllCustomersQuery { CompanyId = companyId }));

        }
        [HttpGet("[action]")]
        public async Task<ActionResult<CustomerDto>> GetCustomerById([FromQuery] int Id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (Id == 0) return BadRequest("Customer ID is required");
            var result = await mediator.Send(new GetCustomerByIdQuery { Id = Id, CompanyId = companyId });
            if (result == null) return NotFound();
            return Ok(result);
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<CustomerDto>> GetCustomerByName([FromQuery] string name, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (string.IsNullOrEmpty(name)) return BadRequest("Customer name is required");
            var result = await mediator.Send(new GetCustomerByNameQuery { Name = name, CompanyId = companyId });
            if (result == null) return NotFound();
            return Ok(result);
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<CustomerDto>> AddCustomercommand([FromBody] CreateCustomerRequest createrequest, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");

            var command = new AddCustomerCommand(createrequest, companyId);

            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetAllCustomers), new { companyId }, result);
        }
        [HttpPatch("[action]")]
        public async Task<ActionResult<CustomerDto>> UpdateCustomercommand([FromBody] UpdateCustomerRequest updaterequest, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (updaterequest.Id == null) return BadRequest("Customer ID is required");
            var command = new UpdateCustomerCommand(updaterequest, companyId);
            var result = await mediator.Send(command);
            return Ok(new { Id = updaterequest.Id, Message = "Customer updated" });
        }
        [HttpDelete("[action]")]
        public async Task<ActionResult> DeleteCustomercommand([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            if (id == 0) return BadRequest("Customer ID is required");
            var command = new DeleteCustomerCommand(id, companyId);
            await mediator.Send(command);
            return Ok(new { Id = id, Message = "Customer deleted" });
        }
    }
}
