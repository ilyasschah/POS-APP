using Api.Commands.DocumentCategoryCommands.Add;
using Api.Commands.DocumentCategoryCommands.Delete;
using Api.Queries.DocumentCategoryQuery;
using Api.Queries.DocumentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentCategoryController(IMediator mediator) : ControllerBase
    {
        //GetAllDocumentCatogory
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentCategoryDto>>> GettAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllDocumentCategoryQuery { CompanyId = companyId }));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentCategoryDto>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetDocumentByIdQuery(id) { CompanyId = companyId }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentCategoryDto>> Create([FromQuery] CreateDocumentCategoryRequest request)
        {
            return Ok(await mediator.Send(new AddDocumentCategoryCommand(request)));
        }
        //DELETE: api/DocumentCategory/delete/5
        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteDocumentCategoryCommand(id)));
        }
    }
}
