using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;
using Api.Commands.CompanyCommands.Add;
using Api.Commands.CompanyCommands.Delete;
using Api.Commands.CompanyCommands.Update;
using Api.Queries.CompanyQuery;
using Api.Models;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class CompanyController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CompanyDto>>> GetAll()
        {
            var companies = await mediator.Send(new GetAllCompaniesQuery());
            return Ok(companies);
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<CompanyDto>> GetById(int id)
        {
            if (id <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetCompanyByIdQuery(id)));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<CompanyDto>> Create([FromBody] CreateCompanyRequest request)
        {
            var command = new AddCompanyCommand(request);
            var createdCompany = await mediator.Send(command);
            return Ok(new
            {
                message = $"Company '{createdCompany.Name}' created successfully.",
            });
        }
        [HttpPatch("[action]")]
        public async Task<ActionResult<CompanyDto>> Update([FromBody] UpdateCompanyRequest req)
        {
            var command = new UpdateCompanyCommand(req);
            var result = await mediator.Send(command);

            return Ok(result);
        }
        [HttpPut("[action]")]
        public async Task<ActionResult> UpdateLogo([FromBody] UpdateCompanyLogoRequest request)
        {
            var command = new UpdateCompanyLogoCommand(request);
            await mediator.Send(command);
            return Ok(new
            {
                message = "Company logo updated successfully.",
            });
        }
        [HttpDelete("[action]")]
        public async Task<ActionResult> Delete(int id)
        {
            var command = new DeleteCompanyCommand(id);
            await mediator.Send(command);
            return Ok(new
            {
                message = "Company deleted successfully.",
            });
        }
    }
}