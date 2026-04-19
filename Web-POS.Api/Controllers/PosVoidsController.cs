using Api.Commands.PosVoidCommands.Add;
using Api.Commands.PosVoidCommands.Update;
using Api.Models;
using Api.Queries.PosVoidQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PosVoidsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetAllPosVoidsQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<PosVoidDto?>> GetById(int id, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPosVoidByIdQuery { Id = id, CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<PosVoidDto>>> GetByOrderNumber(string orderNumber, [FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetPosVoidsByOrderNumberQuery(orderNumber) { CompanyId = companyId }));
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<PosVoidDto>> Add([FromQuery] CreatePosVoidRequest request)
        {
            return Ok(await mediator.Send(new AddPosVoidCommand(request)));
        }
        [HttpPost("[action]")]
        public async Task<IActionResult> Update([FromQuery] UpdatePosVoidRequest request)
        {
            return Ok(await mediator.Send(new UpdatePosVoidCommand (request)));
        }
        //[HttpDelete("Delete/{id}")]
        //public async Task<IActionResult> Delete(string reason)
        //{
        //    return Ok(await mediator.Send(new DeletePosVoidCommand(reason)));
        //}
    }
}