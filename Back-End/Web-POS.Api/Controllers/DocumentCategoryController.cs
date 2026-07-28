using Api.Models;
using Api.Queries.DocumentCategoryQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    // Document categories are a global, read-only reference list shared by all companies.
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentCategoryController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentCategoryDto>>> GetAll(CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new GetAllDocumentCategoryQuery(), ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentCategoryDto>> GetById([FromQuery] int id, CancellationToken ct = default)
        {
            return Ok(await mediator.Send(new GetDCByIdQuery(id), ct));
        }
    }
}
