using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Queries.TaxesQuery.Get;
using Api.Commands.TaxesCommands.Add;
using Api.Commands.TaxesCommands.Update;
using Api.Commands.TaxesCommands.Delete;
using Api.Attributes;
using Api.Models;

namespace Api.Controllers
{
    [SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class TaxesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<TaxDto>>> GetAllTaxes([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllTaxesQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<TaxDto>> GetTaxById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetTaxByIdQuery { Id = id, CompanyId = companyId });
            if (result == null) return NotFound($"Tax with ID {id} not found.");
            return Ok(result);
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<TaxDto>> GetTaxByName([FromQuery] string name, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetByTaxebyNameQuery { Name = name, CompanyId = companyId });
            if (result == null) return NotFound($"Tax with name '{name}' not found.");
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<TaxDto>> AddTax([FromBody] CreateTaxRequestDto createDto, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new AddTaxCommand(createDto, companyId);
            var newTax = await mediator.Send(command);
            return CreatedAtAction(nameof(GetTaxById), new { id = newTax.Id, companyId }, newTax);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult<TaxDto>> UpdateTax([FromBody] UpdateTaxRequestDto req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new UpdateTaxCommand(req, companyId);
            var updatedTax = await mediator.Send(command);
            return Ok(updatedTax);
        }

        [HttpDelete("[action]")]
        public async Task<ActionResult<TaxDto>> DeleteTax([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var success = await mediator.Send(new DeleteTaxCommand(id, companyId));
            if (!success) return NotFound($"Tax with ID {id} not found.");
            return Ok(new { Message = "Tax deleted" });
        }
    }
}