using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ApplicationPropertyCommands.Add;
using Api.Commands.ApplicationPropertyCommands.Update;
using Api.Queries.ApplicationPropertyQuery;
using Api.Models;

namespace Api.Controllers
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

        [HttpGet("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetApplicationPropertyByIdQuery { Id = id, CompanyId = companyId });
            if (result == null) return NotFound($"Application property with ID '{id}' not found");
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> GetByName([FromQuery] string name, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetApplicationPropertyByNameQuery { Name = name, CompanyId = companyId });
            if (result == null) return NotFound($"Application property with name '{name}' not found");
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> Add([FromBody] CreateApplicationPropertyRequest request, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new AddApplicationPropertyCommand(request, companyId);
            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId = companyId }, result);
        }

        [HttpPut("[action]")]
        public async Task<ActionResult<bool>> Update([FromBody] UpdateApplicationPropertyRequest request, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new UpdateApplicationPropertyCommand(request, companyId));
            return Ok(result);
        }
    }
}