using Api.Commands.FloorPlanTableCommands.Add;
using Api.Commands.FloorPlanTableCommands.Delete;
using Api.Commands.FloorPlanTableCommands.Update;
using Api.Models;
using Api.Queries.FloorPlanTableQuery;
using Api.Services;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FloorPlanTablesController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly FloorPlanTableService _service;

        public FloorPlanTablesController(IMediator mediator, FloorPlanTableService service)
        {
            _mediator = mediator;
            _service = service;
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

        [HttpPatch("[action]")]
        public async Task<ActionResult> Update([FromBody] UpdateTablePropertiesRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var success = await _service.UpdatePropertiesAsync(request, companyId);
            if (!success) return NotFound();
            return Ok();
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult> OccupyTable([FromQuery] int tableId, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var success = await _service.OccupyTableAsync(tableId, companyId);
            if (!success) return NotFound();
            return Ok();
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult> FreeTable([FromQuery] int tableId, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();
            var success = await _service.FreeTableAsync(tableId, companyId);
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