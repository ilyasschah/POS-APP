using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;
using Products.Api.Commands.PosOrderCommands.Add;
using Products.Api.Commands.PosOrderCommands.Delete;
using Products.Api.Commands.PosOrderCommands.Update;
using Products.Api.Queries.PosOrderQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PosOrdersController(IMediator mediator) : ControllerBase
    {

        [HttpGet("[action]")]
        public async Task<ActionResult<IEnumerable<PosOrderDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var query = new GetAllPosOrdersQuery { CompanyId = companyId };
            var result = await mediator.Send(query);
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<PosOrderDto>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var query = new GetPosOrderByIdQuery { Id = id, CompanyId = companyId };
            var result = await mediator.Send(query);
            return result != null ? Ok(result) : NotFound();
        }
        [HttpGet("[action]/{number}")]
        public async Task<ActionResult<PosOrderDto>> GetByNumber(string number, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var query = new GetPosOrderByNumberQuery(number) { CompanyId = companyId };
            var result = await mediator.Send(query);
            return result != null ? Ok(result) : NotFound();
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<PosOrderDto>> Add([FromBody] CreatePosOrderRequest req)
        {
            var command = new AddPosOrderCommand(req);
            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }
        [HttpPut("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdatePosOrderRequest req)
        {
            var command = new UpdatePosOrderCommand(id, req);
            var result = await mediator.Send(command);
            return result ? NoContent() : NotFound();
        }
        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var command = new DeletePosOrderCommand(id);
            var result = await mediator.Send(command);
            return result ? NoContent() : NotFound();
        }
    }
}