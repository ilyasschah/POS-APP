using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ApplicationPropertyCommands.Add;
using Api.Commands.ApplicationPropertyCommands.Update;
using Api.Queries.ApplicationPropertyQuery;
using Api.Models;
using Api.Attributes;

namespace Api.Controllers
{
    [SwaggerVisible]
    [ApiController]
    [Route("api/[controller]")]
    public class ApplicationPropertiesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ApplicationPropertyDto>>> GetAll([FromQuery] int companyId, [FromQuery] DateTime? modifiedAfter = null, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetAllApplicationPropertiesQuery { CompanyId = companyId, ModifiedAfter = modifiedAfter }, ct);
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> GetById(int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetApplicationPropertyByIdQuery { Id = id, CompanyId = companyId }, ct);
            if (result == null) return NotFound($"Application property with ID '{id}' not found");
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> GetByName([FromQuery] string name, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetApplicationPropertyByNameQuery { Name = name, CompanyId = companyId }, ct);
            if (result == null) return NotFound($"Application property with name '{name}' not found");
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<ApplicationPropertyDto>> Add([FromBody] CreateApplicationPropertyRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new AddApplicationPropertyCommand(request, companyId);
            var result = await mediator.Send(command, ct);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId = companyId }, result);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult<bool>> Update([FromBody] UpdateApplicationPropertyRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new UpdateApplicationPropertyCommand(request, companyId), ct);
            return Ok(result);
        }
    }
}