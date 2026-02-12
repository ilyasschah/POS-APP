using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ApplicationPropertyCommands.Add;
//using Products.Api.Commands.ApplicationPropertyCommands.Delete;
using Products.Api.Commands.ApplicationPropertyCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.ApplicationPropertyQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ApplicationPropertiesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ApplicationPropertyDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetAllApplicationPropertiesQuery { CompanyId = companyId });
            return Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<ApplicationPropertyDto>> GetByName(string name, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetApplicationPropertyByNameQuery(name, companyId)));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> Add([FromQuery] CreateApplicationPropertyRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new AddApplicationPropertyCommand(req, companyId);
            var result = await mediator.Send(command);
            return Ok(new
            { 
                message = $"Application property {result.Name} added successfully",
            });
        }

        [HttpPut("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> Update([FromQuery] UpdateApplicationPropertyRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new UpdateApplicationPropertyCommand(req, companyId));
            return Ok(new
            {
                message = $"Application property {result.Name} updated successfully",
            });
        }

        //[HttpDelete("[action]/{name}")]
        //public async Task<IActionResult> Delete(string name, [FromQuery] int companyId)
        
        //    var ok = await mediator.Send(new DeleteApplicationPropertyCommand(name, companyId));
        //    return ok ? NoContent() : NotFound();
    }
}
