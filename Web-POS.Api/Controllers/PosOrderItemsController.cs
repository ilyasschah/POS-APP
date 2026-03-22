using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.PosOrderItemCommands.Add;
using Api.Commands.PosOrderItemCommands.Delete;
using Api.Commands.PosOrderItemCommands.Update;
using Api.Queries.PosOrderItemQuery;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PosOrderItemsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosOrderItemDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllPosOrderItemsQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]/{id}")]
        public async Task<ActionResult> GetById(int id)
        {
            return Ok(await mediator.Send(new GetPosOrderItemByIdQuery(id)));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult> Add([FromQuery] CreatePosOrderItemRequest request)
        {
            var command = new AddPosOrderItemCommand(request);
            var newId = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = newId }, request);
        }

        [HttpPut("[action]")]
        public async Task<ActionResult> Update([FromQuery] UpdatePosOrderItemRequest request)
        {
            var command = new UpdatePosOrderItemCommand(request);
            await mediator.Send(command);
            return NoContent();
        }

        [HttpDelete("[action]/{id}")]
        public async Task<ActionResult> Delete(int id)
        {
            return await mediator.Send(new DeletePosOrderItemCommand(id)) ? NoContent() : NotFound();
        }
    }
}

