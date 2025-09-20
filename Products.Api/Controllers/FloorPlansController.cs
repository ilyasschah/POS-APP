using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Models;
using Products.Api.Commands.FloorPlanCommands.Add;
using Products.Api.Commands.FloorPlanCommands.Delete;
using Products.Api.Commands.FloorPlanCommands.Update;
using Products.Api.Queries.FloorPlanQuery.Get;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FloorPlansController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<FloorPlanDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllFloorPlansQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<FloorPlanDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetFloorPlanByIdQuery { Id = id });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<FloorPlanDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetFloorPlanByNameQuery { Name = name });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<FloorPlanDto>> Add([FromQuery] CreateFloorPlanRequest req)
        {
            var result = await mediator.Send(new AddFloorPlanCommand { Request = req });
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateFloorPlanRequest req)
        {
            var result = await mediator.Send(new UpdateFloorPlanCommand { Id = id, Request = req });
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await mediator.Send(new DeleteFloorPlanCommand { Id = id });
            return result ? NoContent() : NotFound();
        }
    }
}