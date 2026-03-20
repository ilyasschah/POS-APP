using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;
using Products.Api.Queries.TaxesQuery.Get;
using Products.Api.Commands.TaxesCommands.Add;
using Products.Api.Commands.TaxesCommands.Update;
using Products.Api.Commands.TaxesCommands.Delete;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TaxesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<TaxDto>>> GetAllTaxes(int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllTaxesQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<TaxDto>> GetTaxById(int id,int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetTaxByIdQuery { Id = id, CompanyId = companyId });
            if (result == null) return NotFound($"Tax with ID {id} not found.");
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<TaxDto>> AddTax([FromBody] CreateTaxRequestDto createDto, int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new AddTaxCommand(createDto, companyId);
            var newTax = await mediator.Send(command);
            return CreatedAtAction(nameof(GetTaxById), new { id = newTax.Id, companyId = companyId }, newTax);
        }

        [HttpPut("[action]")]
        public async Task<ActionResult<TaxDto>> UpdateTax(UpdateTaxRequestDto req,int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new UpdateTaxCommand(req, companyId);
            var updatedTax = await mediator.Send(command);
            return Ok(updatedTax);
        }

        [HttpDelete("[action]")]
        public async Task<ActionResult<bool>> DeleteTax(int id, int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var success = await mediator.Send(new DeleteTaxCommand(id, companyId));
            if (!success) return NotFound($"Tax with ID {id} not found.");
            return Ok(true);
        }
    }
}