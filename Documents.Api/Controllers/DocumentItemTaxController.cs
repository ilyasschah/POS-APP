using Documents.Api.Commands.DocumentItemTaxCommands.Add;
using Documents.Api.Commands.DocumentItemTaxCommands.Delete;
using Documents.Api.Commands.DocumentItemTaxCommands.Update;
using Documents.Api.Models;
using Documents.Api.Queries.DocumentItemTaxQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Documents.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentItemTaxController (IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]/{documentitemid:int}")]
        public async Task<ActionResult<List<DocumentItemTaxDto?>>> GetByDocumentItemId(int documentitemid)
        {
            return Ok(await mediator.Send(new GetByDocumentitemTaxByIdQuery(documentitemid)));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentItemTaxDto>> Add([FromBody] CreateDocumentItemTaxRequest req)
        {
            return Ok(await mediator.Send(new AddDocumentItemtaxCommand(req)));
        }
        [HttpPost("[action]")]
        public async Task<IActionResult> Update([FromQuery] UpdateDocumentItemTaxRequest updaterequest)
        {
            return Ok(await mediator.Send(new UpdateDocumentitemtaxamountcommand(updaterequest)));
        }
        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            return Ok(await mediator.Send(new DeleteDocumentItemTaxCommand(id)));
        }
    }
}
