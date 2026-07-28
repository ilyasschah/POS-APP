using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Queries.CountryQuery.Get;
using Api.Models;

namespace Api.Controllers
{
    // Countries are a global, read-only reference list shared by all companies.
    [Route("api/[controller]")]
    [ApiController]
    public class CountryController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CountryDto>>> GetAllCountries(CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new GetAllCountriesQuery(), ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<CountryDto>> GetById(int id, CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new GetCountryByIdQuery(id), ct));
        }
    }
}
