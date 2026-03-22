using Api.Attributes;
using Api.Commands.DocumentCategoryCommands.Add;
using Api.Commands.DocumentCategoryCommands.Delete;
using Api.Models;
using Api.Queries.DocumentCategoryQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentCategoryController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentCategoryDto>>> GettAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllDocumentCategoryQuery { CompanyId = companyId }));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentCategoryDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetDCByIdQuery(id, companyId)));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentCategoryDto>> Create([FromBody] CreateDocumentCategoryRequest request, [FromQuery] int companyId)
        {
            return Ok(await mediator.Send(new AddDocumentCategoryCommand(request, companyId)));
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            return Ok(await mediator.Send(new DeleteDocumentCategoryCommand(id, companyId)));
        }
    }
}
