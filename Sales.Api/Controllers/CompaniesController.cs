using MediatR;
using Microsoft.AspNetCore.Mvc;
using Sales.Api.Commands.CompanyCommands.Add;
using Sales.Api.Commands.CompanyCommands.Update;
using Sales.Api.Commands.CompanyCommands.Delete;
using Sales.Api.Models;
using Sales.Api.Queries.CompanyQuery;

namespace Sales.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CompaniesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CompanyDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllCompanysQuery()));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult> Add([FromBody] CreateCompanyRequest createRequest)
        {
            return Ok(await mediator.Send(new AddCompanyCommand(createRequest)));
        }

        [HttpPut("[action]")]
        public async Task<IActionResult> Update([FromQuery] UpdateCompanyRequest updateRequest)
        {
            return Ok(await mediator.Send(new UpdateCompanyCommand(updateRequest)));
        }

        [HttpDelete("delete/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteCompanyCommand(id)));
        }
    }
}



