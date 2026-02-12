using Products.Api.Commands.DocumentCategoryCommands.Add;
using Products.Api.Commands.DocumentCategoryCommands.Delete;
using Products.Api.Queries.DocumentCategoryQuery;
using Products.Api.Queries.DocumentQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentCategoryController(IMediator mediator) : ControllerBase
    {
        //GetAllDocumentCatogory
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentCategoryDto>>> GettAll()
        {
            return Ok(await mediator.Send(new GetAllDocumentCategoryQuery()));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentCategoryDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetDocumentByIdQuery(id)));
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
