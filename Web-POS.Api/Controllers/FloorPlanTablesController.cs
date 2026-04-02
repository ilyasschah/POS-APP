using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Models;
using Api.Queries.FloorPlanTableQuery;
using Api.Commands.FloorPlanTableCommand.Add;
using Api.Commands.FloorPlanTableCommand.Update;
using Api.Commands.FloorPlanTableCommand.Delete;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FloorPlanTablesController : ControllerBase
    {
        private readonly IMediator _mediator;

        public FloorPlanTablesController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<FloorPlanTableDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            return Ok(await _mediator.Send(new GetAllFloorPlanTablesQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<FloorPlanTableDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var result = await _mediator.Send(new GetFloorPlanTableByIdQuery { Id = id, CompanyId = companyId });
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<FloorPlanTableDto>> GetByName([FromQuery] string name, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var result = await _mediator.Send(new GetFloorPlanTableByNameQuery { Name = name, CompanyId = companyId });
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<FloorPlanTableDto>>> GetByFloorPlanId([FromQuery] int floorPlanId, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            return Ok(await _mediator.Send(new GetFloorPlanTablesByFloorPlanIdQuery { FloorPlanId = floorPlanId, CompanyId = companyId }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<FloorPlanTableDto>> Add([FromBody] CreateFloorPlanTableRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var result = await _mediator.Send(new AddFloorPlanTableCommand { Request = request, CompanyId = companyId });
            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult> UpdateGeometry([FromBody] UpdateTableGeometryRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var success = await _mediator.Send(new UpdateFloorPlanTableCommand { Request = request, CompanyId = companyId });
            if (!success) return NotFound();
            return Ok();
        }

        [HttpDelete("[action]")]
        public async Task<ActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var success = await _mediator.Send(new DeleteFloorPlanTableCommand { Id = id, CompanyId = companyId });
            if (!success) return NotFound();
            return Ok();
        }
    }
}