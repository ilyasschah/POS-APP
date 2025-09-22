using Products.Api.Commands.DocumentItemTaxCommands.Add;
using Products.Api.Commands.DocumentItemTaxCommands.Delete;
using Products.Api.Commands.DocumentItemTaxCommands.Update;
using Products.Api.Queries.DocumentItemTaxQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;

namespace Products.Api.Controllers
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
