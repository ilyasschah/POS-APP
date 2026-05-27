using Api.Commands.FloorPlanCommands.Add;
using Api.Commands.FloorPlanCommands.Delete;
using Api.Commands.FloorPlanCommands.Update;
using Api.Models;
using Api.Queries.FloorPlanQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FloorPlansController : ControllerBase
    {
        private readonly IMediator _mediator;

        public FloorPlansController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<FloorPlanDto>>> GetAll([FromQuery] int companyId, [FromQuery] DateTime? modifiedAfter = null)
        {
            if (companyId == 0) return BadRequest();

            var result = await _mediator.Send(new GetAllFloorPlansQuery { CompanyId = companyId, ModifiedAfter = modifiedAfter });
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<FloorPlanDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();

            var result = await _mediator.Send(new GetFloorPlanByIdQuery { Id = id, CompanyId = companyId });
            if (result == null) return NotFound();

            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<FloorPlanDto>> Add([FromBody] CreateFloorPlanRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();

            var result = await _mediator.Send(new AddFloorPlanCommand { Request = request, CompanyId = companyId });
            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<ActionResult> Update([FromBody] UpdateFloorPlanRequest request, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();

            var success = await _mediator.Send(new UpdateFloorPlanCommand { Request = request, CompanyId = companyId });
            if (!success) return NotFound();

            return Ok();
        }

        [HttpDelete("[action]")]
        public async Task<ActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest();

            var success = await _mediator.Send(new DeleteFloorPlanCommand { Id = id, CompanyId = companyId });
            if (!success) return NotFound();

            return Ok();
        }
    }
}