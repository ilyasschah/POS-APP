using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.FloorPlanTableCommands.Add;
using Api.Commands.FloorPlanTableCommands.Delete;
using Api.Commands.FloorPlanTableCommands.Update;
using Api.Queries.FloorPlanTableQuery.Get;
using System.Collections.Generic;
using System.Threading.Tasks;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class FloorPlanTablesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<FloorPlanTableDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllFloorPlanTablesQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<FloorPlanTableDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetFloorPlanTableByIdQuery { Id = id });
            return result != null ? Ok(result) : NotFound();
        }

        [HttpGet("[action]/ByFloorPlan/{floorPlanId:int}")]
        public async Task<ActionResult<List<FloorPlanTableDto>>> GetByFloorPlanId(int floorPlanId)
        {
            var result = await mediator.Send(new GetFloorPlanTablesByFloorPlanIdQuery { FloorPlanId = floorPlanId });
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<FloorPlanTableDto>> Add([FromQuery] CreateFloorPlanTableRequest req)
        {
            var result = await mediator.Send(new AddFloorPlanTableCommand { Request = req });
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateFloorPlanTableRequest req)
        {
            var result = await mediator.Send(new UpdateFloorPlanTableCommand { Id = id, Request = req });
            return result ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var result = await mediator.Send(new DeleteFloorPlanTableCommand { Id = id });
            return result ? NoContent() : NotFound();
        }
    }
}