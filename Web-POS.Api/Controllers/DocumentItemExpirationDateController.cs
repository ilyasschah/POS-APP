using Products.Api.Commands.DocumentItemExpirationDateCommands.Add;
using Products.Api.Commands.DocumentItemExpirationDateCommands.Delete;
using Products.Api.Commands.DocumentItemExpirationDateCommands.Update;
using Products.Api.Queries.DocumentItemExpirationDateQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DocumentItemExpirationDateController(IMediator mediator) : ControllerBase
    {
        // GET: api/DocumentItemExpirationDate/id
        [HttpGet("[action]")]
        public async Task<ActionResult<List<DocumentItemExpirationDateDto>>> GetAll()
        {
            return Ok(await mediator.Send(new GetAllDocumentItemExpirationDateQuery()));
        }
        // GET: api/DocumentItemExpirationDate/id
        [HttpGet("[action]")]
        public async Task<ActionResult<DocumentItemExpirationDateDto>> GetById(int id)
        {
            return Ok(await mediator.Send(new GetExpDateByDocumentIdQuery(id)));
        }
        //POST: api/DocumentItemExpirationDate
        [HttpPost("[action]")]
        public async Task<ActionResult<DocumentItemExpirationDateDto>> Add([FromQuery] CreateDocumentItemExpirationDateRequest createrequest)
        {
            return Ok(await mediator.Send(new CreateExpirationDateByDocumentItemIdCommand(createrequest)));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult> Update([FromQuery] UpdateDocumentItemExpirationDateRequest updaterequest)
        {
            return Ok(await mediator.Send(new UpdateDocumentItemExpirationDateCommand(updaterequest)));
        }
        [HttpDelete("Delete/{id}")]
        public async Task<ActionResult> Delete([FromQuery] int id)
        {
            return Ok(await mediator.Send(new DeleteDocumentItemExpirationDateCommand(id)));
        }
    }
}
