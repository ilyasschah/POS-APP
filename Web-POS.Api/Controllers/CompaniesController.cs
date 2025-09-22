using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.CompanyCommands.Add;
using Products.Api.Commands.CompanyCommands.Update;
using Products.Api.Commands.CompanyCommands.Delete;
using Products.Api.Queries.CompanyQuery;
using Products.Api.Models;

namespace Products.Api.Controllers
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



