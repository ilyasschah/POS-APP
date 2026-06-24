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
        public async Task<ActionResult<List<CountryDto>>> GetAllCountries()
        {
            return Ok(await mediator.Send(new GetAllCountriesQuery()));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<CountryDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetCountryByIdQuery(id)));
        }
    }
}
