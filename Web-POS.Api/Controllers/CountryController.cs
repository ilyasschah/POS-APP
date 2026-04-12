using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.CountryCommands.Add;
using Api.Commands.CountryCommands.Update;
using Api.Commands.CountryCommands.Delete;
using Api.Queries.CountryQuery.Get;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CountryController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CountryDto>>> GetAllCountries([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok (await mediator.Send(new GetAllCountriesQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<CountryDto>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetCountryByIdQuery(id) { CompanyId = companyId }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<CountryDto>> Add([FromBody] CreateCountryRequest createrequest, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var command = new AddCountryCommand(createrequest, companyId);
            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = 0, companyId }, result);
        }

        [HttpPut("[action]")]
        public async Task<IActionResult> Update(int id, [FromBody] UpdateCountryRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var ok = await mediator.Send(new UpdateCountryCommand(id, req, companyId));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete(int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var ok = await mediator.Send(new DeleteCountryCommand(id, companyId));
            return ok ? NoContent() : NotFound();
        }
    }
}
